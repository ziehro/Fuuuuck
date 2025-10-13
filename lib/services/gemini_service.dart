// lib/services/gemini_service.dart
// Hybrid: Gemini for text generation + OpenAI for image generation

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:mybeachbook/services/api/secrets.dart';

class GeminiService {
  static const String _uploadFolder = 'beach_images';
  late final GenerativeModel _textModel;

  // OpenAI endpoints for image generation
  static const String _openaiBaseUrl = 'https://api.openai.com/v1';

  GeminiService() {
    _textModel = GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: geminiApiKey,
    );
  }

  /// Build a single-paragraph beach description using Gemini (cheap: $0.00015/1K tokens)
  Future<String> generateBeachDescription({
    required String beachName,
    required Map<String, dynamic> userAnswers,
  }) async {
    final facts = _extractFacts(userAnswers);

    final prompt = '''
You write concise (120–180 words), visitor-friendly beach summaries.
You MUST only use the provided structured facts.
Do NOT invent locations, animals, amenities, weather, or anything not explicitly present.
Interpret numeric values where any number > 1 indicates presence; use their "level" field to guide wording.
Prefer clear, concrete phrasing. No bullet lists.

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
      final response = await _textModel.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? 'No description could be generated.';
    } catch (e) {
      debugPrint('Gemini text error: $e');
      return 'Failed to generate AI description.';
    }
  }

  /// Generate an image with OpenAI DALL-E 3 and upload to Firebase
  Future<GeminiInfo> getInfoAndImage(
      String subject, {
        String? description,
      }) async {
    try {
      final finalDescription = description ?? await _generateDescription(subject);

      final imagePrompt =
          'Create a high-quality, realistic photo-style image of this beach scene. '
          'Do not add extra elements beyond what is implied. Scene:\n$finalDescription';

      debugPrint('Generating image with OpenAI DALL-E 3...');

      final imageBytes = await _generateImageWithOpenAI(imagePrompt);

      if (imageBytes == null) {
        debugPrint('OpenAI: no image data returned');
        return GeminiInfo(
          description: finalDescription,
          image: const Icon(Icons.image_not_supported),
          imageUrl: '',
        );
      }

      // Add watermark to distinguish AI images
      debugPrint('Adding AI watermark...');
      final watermarkedBytes = await _addAiWatermark(imageBytes);

      debugPrint('Image generated (${watermarkedBytes.length} bytes), uploading to Firebase...');
      final url = await _uploadPngAsUserFlow(watermarkedBytes);

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
      debugPrint('OpenAI->Firebase error: $e');
      return GeminiInfo(
        description: description ?? 'Could not load information.',
        image: const Icon(Icons.error),
        imageUrl: '',
      );
    }
  }

  /// Generate image using OpenAI DALL-E 3
  Future<Uint8List?> _generateImageWithOpenAI(String prompt) async {
    try {
      final url = Uri.parse('$_openaiBaseUrl/images/generations');

      final requestBody = {
        'model': 'dall-e-3',
        'prompt': prompt,
        'n': 1,
        'size': '1024x1024',
        'response_format': 'b64_json',
      };

      debugPrint('Sending image request to OpenAI DALL-E 3...');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $openAIApiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode != 200) {
        debugPrint('OpenAI API error: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return null;
      }

      final responseData = json.decode(response.body);
      final data = responseData['data'] as List?;

      if (data == null || data.isEmpty) {
        debugPrint('No image data in response');
        return null;
      }

      final base64Image = data[0]['b64_json'] as String?;

      if (base64Image != null) {
        debugPrint('Found image data, decoding...');
        return base64Decode(base64Image);
      }

      debugPrint('No b64_json found in response');
      return null;
    } catch (e) {
      debugPrint('Error generating image with OpenAI: $e');
      return null;
    }
  }

  /// Add a subtle AI watermark to the image
  Future<Uint8List> _addAiWatermark(Uint8List imageBytes) async {
    try {
      // Import required for image manipulation
      final codec = await ui.instantiateImageCodec(imageBytes);
      final frameInfo = await codec.getNextFrame();
      final originalImage = frameInfo.image;

      // Create a canvas to draw on
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final size = Size(
        originalImage.width.toDouble(),
        originalImage.height.toDouble(),
      );

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
        size.width - textPainter.width - (size.width * 0.02),
        size.height - textPainter.height - (size.height * 0.02),
      );

      textPainter.paint(canvas, watermarkOffset);

      // Convert back to bytes
      final picture = recorder.endRecording();
      final watermarkedImage = await picture.toImage(
        originalImage.width,
        originalImage.height,
      );

      final byteData = await watermarkedImage.toByteData(
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

  Future<String> _generateDescription(String subject) async {
    final prompt =
        'Provide a short, educational description (2–3 sentences) strictly about: "$subject". '
        'Do not add unrelated details.';

    try {
      final response = await _textModel.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? 'No description available.';
    } catch (e) {
      debugPrint('Gemini description error: $e');
      return 'No description available.';
    }
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