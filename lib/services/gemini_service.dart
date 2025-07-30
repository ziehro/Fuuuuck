// lib/services/gemini_service.dart
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:fuuuuck/services/api/secrets.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GeminiService {
  final GenerativeModel _model;
  final String _googleSearchApiKey = googleApiKey;
  final String _googleSearchEngineId = googleSearchId;

  GeminiService()
      : _model = GenerativeModel(
    model: 'gemini-pro',
    apiKey: geminiApiKey,
    generationConfig: GenerationConfig(maxOutputTokens: 200),
  );

  Future<String> generateBeachDescription({
    required String beachName,
    required Map<String, dynamic> userAnswers,
  }) async {
    final prompt =
        'Create a compelling, paragraph-long description for a beach named "$beachName". '
        'Incorporate the following user-observed details: ${userAnswers.toString()}. '
        'Focus on painting a vivid picture for a potential visitor. Do not just list the features.';
    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? 'No description could be generated.';
    } catch (e) {
      print('Error generating beach description: $e');
      return 'Failed to generate AI description.';
    }
  }

  Future<GeminiInfo> getInfoAndImage(String subject, {String? description}) async {
    try {
      // Use the provided description if available, otherwise generate a new one.
      final String finalDescription = description ?? await _generateDescription(subject);

      // Fetch a relevant image from Google Custom Search
      final imageUrl = await _getImageUrl(subject);
      final imageWidget = (imageUrl != null)
          ? Image.network(imageUrl, fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.error))
          : const Icon(Icons.image_not_supported);

      return GeminiInfo(description: finalDescription, image: imageWidget);
    } catch (e) {
      print('Error in getInfoAndImage: $e');
      return GeminiInfo(description: 'Could not load information.', image: const Icon(Icons.error));
    }
  }

  Future<String> _generateDescription(String subject) async {
    final prompt = 'Provide a short, educational description (about 2-3 sentences) for the following subject: $subject.';
    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text ?? 'No description available.';
  }

  Future<String?> _getImageUrl(String query) async {
    final url = Uri.parse(
        'https://www.googleapis.com/customsearch/v1?key=$_googleSearchApiKey&cx=$_googleSearchEngineId&q=${Uri.encodeComponent(query)}&searchType=image&num=1');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['items'] != null && data['items'].isNotEmpty) {
          return data['items'][0]['link'];
        }
      }
      return null;
    } catch (e) {
      print('Error fetching image from Google Search: $e');
      return null;
    }
  }
}

class GeminiInfo {
  final String description;
  final Widget image;

  GeminiInfo({required this.description, required this.image});
}