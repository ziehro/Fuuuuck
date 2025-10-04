// lib/services/gemini_service.dart
// Enhanced with AI image watermarking

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:mybeachbook/services/api/secrets.dart';

class GeminiService {
  static const String _uploadFolder = 'beach_images';

  GeminiService() {
    OpenAI.apiKey = openAIApiKey;
  }

  /// Build a single-paragraph beach description using ONLY facts from userAnswers
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

  /// Generate an image with AI watermark and upload to Firebase
  Future<GeminiInfo> getInfoAndImage(
      String subject, {
        String? description,
      }) async {
    try {
      final finalDescription = description ?? await _generateDescription(subject);

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

      // Decode base64 -> add watermark -> upload
      final originalBytes = base64Decode(img.data.first.b64Json!);
      final watermarkedBytes = await _addAiWatermark(originalBytes);
      final url = await _uploadPngAsUserFlow(watermarkedBytes);

      debugPrint('Uploaded watermarked image URL: $url');

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

  /// Add a subtle AI watermark to the image
  Future<Uint8List> _addAiWatermark(Uint8List imageBytes) async {
    try {
      // Decode the image
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image originalImage = frameInfo.image;

      // Create a canvas to draw on
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(originalImage.width.toDouble(), originalImage.height.toDouble());

      // Draw the original image
      canvas.drawImage(originalImage, Offset.zero, Paint());

      // Create watermark text
      const watermarkText = 'AI Generated';
      final textStyle = TextStyle(
        color: Colors.white.withOpacity(0.7),
        fontSize: size.width * 0.03, // 3% of image width
        fontWeight: FontWeight.w600,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.5),
            offset: const Offset(1, 1),
            blurRadius: 2,
          ),
        ],
      );

      final textSpan = TextSpan(text: watermarkText, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // Position watermark at bottom-right corner with padding
      final watermarkOffset = Offset(
        size.width - textPainter.width - (size.width * 0.02), // 2% padding from right
        size.height - textPainter.height - (size.height * 0.02), // 2% padding from bottom
      );

      textPainter.paint(canvas, watermarkOffset);

      // Convert back to bytes
      final picture = recorder.endRecording();
      final ui.Image watermarkedImage = await picture.toImage(
        originalImage.width,
        originalImage.height,
      );

      final ByteData? byteData = await watermarkedImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      originalImage.dispose();
      watermarkedImage.dispose();

      return byteData!.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error adding watermark: $e');
      // Return original image if watermarking fails
      return imageBytes;
    }
  }

  // ... [Rest of your existing methods remain the same]

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

  Future<String> _uploadPngAsUserFlow(Uint8List bytes) async {
    await _ensureSignedIn();

    final dir = await getTemporaryDirectory();
    final fname = '${const Uuid().v4()}.png';
    final fpath = '${dir.path}/$fname';
    final file = File(fpath);
    await file.writeAsBytes(bytes, flush: true);

    final path = '$_uploadFolder/$fname';
    final ref = FirebaseStorage.instance.ref(path);
    final metadata = SettableMetadata(contentType: 'image/png');

    await ref.putFile(file, metadata);
    return ref.getDownloadURL();
  }

  Future<void> _ensureSignedIn() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
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
  final String imageUrl;

  GeminiInfo({
    required this.description,
    required this.image,
    required this.imageUrl,
  });
}