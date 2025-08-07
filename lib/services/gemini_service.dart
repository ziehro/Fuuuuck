// lib/services/gemini_service.dart
// Facts-only beach description + DALL·E image generation,
// upload via the same flow as user uploads (putFile to Firebase Storage).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:fuuuuck/services/api/secrets.dart';

class GeminiService {
  // Set this to the SAME folder you use for user uploads so rules/flow are identical.
  // If your user flow uses a different folder, change it here to match.
  static const String _uploadFolder = 'beach_images';

  GeminiService() {
    OpenAI.apiKey = openAIApiKey; // put your OpenAI key in secrets.dart
  }

  // --- Public API -------------------------------------------------------------

  /// Build a single-paragraph (120–180 words) description using ONLY facts from [userAnswers].
  /// Any numeric value > 1 is considered "present" and mapped to an intensity word.
  Future<String> generateBeachDescription({
    required String beachName,
    required Map<String, dynamic> userAnswers,
  }) async {
    final facts = _extractFacts(userAnswers);

    final systemPrompt =
        'You write concise (120–180 words), visitor-friendly beach summaries. '
        'You MUST only use the provided structured facts. '
        'Do NOT invent locations, animals, amenities, weather, or anything not explicitly present. '
        'Interpret numeric values where any number > 1 indicates presence; use their "level" field to guide wording. '
        'Prefer clear, concrete phrasing. No bullet lists.';

    final userPrompt = '''
Beach name: "$beachName"

Structured facts (JSON):
${const JsonEncoder.withIndent('  ').convert(facts)}

Instructions:
- Write 1 paragraph (120–180 words) describing the beach.
- Mention only items whose "present" is true (or where "text" exists).
- Reflect intensity using the "level" values (e.g., "a little driftwood", "moderate seaweed", "abundant boulders").
- If no category is present, do not mention it.
- Absolutely no assumptions beyond this JSON.
''';

    try {
      final res = await OpenAI.instance.chat.create(
        model: 'gpt-4o-mini',
        messages: [
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(systemPrompt),
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: [
              OpenAIChatCompletionChoiceMessageContentItemModel.text(userPrompt),
            ],
          ),
        ],
        maxTokens: 260,
        temperature: 0.5,
      );

      return res.choices.first.message.content?.first.text?.trim() ??
          'No description could be generated.';
    } catch (e) {
      debugPrint('OpenAI text error: $e');
      return 'Failed to generate AI description.';
    }
  }

  /// Generate an image that matches the [description] (preferred) and upload it to Firebase.
  /// If [description] is null, falls back to a tiny factual blurb from [subject].
  ///
  /// NOTE: For facts-only behavior, call [generateBeachDescription(...)] first and pass its
  /// result as [description] so the image follows those facts exactly.
  Future<GeminiInfo> getInfoAndImage(
      String subject, {
        String? description,
      }) async {
    try {
      final finalDescription = description ?? await _generateDescription(subject);

      // Create realistic, photo-style image matching the description
      final imagePrompt =
          'Create a high-quality, realistic photo-style image of this beach scene. '
          'Do not add extra elements beyond what is implied. Scene:\n$finalDescription';

      final img = await OpenAI.instance.image.create(
        prompt: imagePrompt,
        n: 1,
        size: OpenAIImageSize.size1024,
        responseFormat: OpenAIImageResponseFormat.b64Json,
      );

      if (!img.haveData || img.data.isEmpty || img.data.first.b64Json == null) {
        debugPrint('OpenAI image: no data returned');
        return GeminiInfo(
          description: finalDescription,
          image: const Icon(Icons.image_not_supported),
          imageUrl: '',
        );
      }

      // Decode base64 → write to temp file → upload with putFile (same as user flow)
      final bytes = base64Decode(img.data.first.b64Json!);
      final url = await _uploadPngAsUserFlow(bytes);

      debugPrint('Uploaded image URL: $url');

      final imageWidget = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.error),
      );

      return GeminiInfo(
        description: finalDescription,
        image: imageWidget,
        imageUrl: url,
      );
    } catch (e) {
      debugPrint('OpenAI image->Firebase error: $e');
      return GeminiInfo(
        description: description ?? 'Could not load information.',
        image: const Icon(Icons.error),
        imageUrl: '',
      );
    }
  }

  // --- Private helpers --------------------------------------------------------

  // If you ever need a tiny fallback description from just a subject.
  Future<String> _generateDescription(String subject) async {
    final prompt =
        'Provide a short, educational description (2–3 sentences) strictly about: "$subject". '
        'Do not add unrelated details.';
    final res = await OpenAI.instance.chat.create(
      model: 'gpt-4o-mini',
      messages: [
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.user,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(prompt),
          ],
        ),
      ],
      maxTokens: 150,
      temperature: 0.3,
    );
    return res.choices.first.message.content?.first.text?.trim() ??
        'No description available.';
  }

  // Mirror the user upload flow: write to temp file, then putFile to same folder.
  Future<String> _uploadPngAsUserFlow(Uint8List bytes) async {
    await _ensureSignedIn();

    // 1) Write to temp
    final dir = await getTemporaryDirectory();
    final fname = '${const Uuid().v4()}.png';
    final fpath = '${dir.path}/$fname';
    final file = File(fpath);
    await file.writeAsBytes(bytes, flush: true);

    // 2) putFile to the SAME path pattern user uploads use
    final path = '$_uploadFolder/$fname';
    final ref = FirebaseStorage.instance.ref(path);
    final metadata = SettableMetadata(contentType: 'image/png');

    await ref.putFile(file, metadata);

    // 3) Get a durable download URL
    return ref.getDownloadURL();
  }

  Future<void> _ensureSignedIn() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      // Use your real sign-in flow if you require identified users.
      await auth.signInAnonymously();
    }
  }

  String _levelWord(num v) {
    if (v <= 1) return 'none';
    if (v <= 2) return 'a little';
    if (v <= 3) return 'some';
    if (v <= 4) return 'moderate';
    if (v <= 5) return 'a lot';
    return 'abundant';
  }

  /// Converts the raw userAnswers into a strict facts map the model must follow.
  /// - Numbers: >1 → present=true and a human intensity word
  /// - bool: present
  /// - non-empty strings: text
  Map<String, dynamic> _extractFacts(Map<String, dynamic> userAnswers) {
    final facts = <String, dynamic>{};
    userAnswers.forEach((key, raw) {
      if (raw is num) {
        final present = raw > 1;
        facts[key] = {
          'value': raw,
          'present': present,
          'level': _levelWord(raw),
        };
      } else if (raw is bool) {
        facts[key] = {'present': raw, 'level': raw ? 'some' : 'none'};
      } else if (raw is String && raw.trim().isNotEmpty) {
        facts[key] = {'text': raw.trim()};
      } else if (raw != null) {
        facts[key] = raw;
      }
    });
    return facts;
  }
}

class GeminiInfo {
  final String description;
  final Widget image;
  final String imageUrl; // store in Firestore or reuse later

  GeminiInfo({
    required this.description,
    required this.image,
    required this.imageUrl,
  });
}
