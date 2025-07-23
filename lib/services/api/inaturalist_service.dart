// lib/services/api/inaturalist_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class INaturalistService {
  static const String _baseUrl = 'https://api.inaturalist.org/v2/';
  static const String _authUrl = 'https://www.inaturalist.org/oauth/token';
  String? _apiToken;

  // --- MOCK DATA IMPLEMENTATION ---
  // Set this to false once you have a real API key
  final bool useMockData = true;

  Future<List<dynamic>> _getMockSuggestions() async {
    // Simulate a network delay
    await Future.delayed(const Duration(seconds: 2));
    debugPrint('Returning mock iNaturalist suggestions.');
    return [
      {
        "taxon": {
          "id": 47700,
          "name": "Symphyotrichum subspicatum",
          "preferred_common_name": "Douglas's Aster",
          "default_photo": { "url": "https://static.inaturalist.org/photos/109939941/large.jpg" }
        },
        "score": 0.85
      },
      {
        "taxon": {
          "id": 50633,
          "name": "Plantago lanceolata",
          "preferred_common_name": "English Plantain",
          "default_photo": { "url": "https://static.inaturalist.org/photos/110999507/large.jpg" }
        },
        "score": 0.05
      }
    ];
  }

  Future<Map<String, dynamic>> _getMockTaxonDetails() async {
    await Future.delayed(const Duration(seconds: 1));
    debugPrint('Returning mock taxon details.');
    return {
      "wikipedia_summary": "Symphyotrichum subspicatum, commonly known as Douglas's aster, is a species of flowering plant in the family Asteraceae. It is native to western North America."
    };
  }
  // --- END OF MOCK DATA ---


  Future<String?> _getApiToken() async {
    if (_apiToken != null) return _apiToken;
    final appId = dotenv.env['INATURALIST_APP_ID'];
    final appSecret = dotenv.env['INATURALIST_APP_SECRET'];
    if (appId == null || appSecret == null) throw Exception('.env file not found');

    try {
      final response = await http.post(
        Uri.parse(_authUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'client_id': appId,
          'client_secret': appSecret,
          'grant_type': 'client_credentials',
        }),
      );
      if (response.statusCode == 200) {
        _apiToken = json.decode(response.body)['access_token'];
        return _apiToken;
      }
    } catch (e) {
      debugPrint('Error getting API token: $e');
    }
    return null;
  }

  Future<List<dynamic>> identifyImage(File imageFile) async {
    if (useMockData) return _getMockSuggestions();

    final token = await _getApiToken();
    if (token == null) throw Exception('Could not get API token.');

    final uri = Uri.parse('${_baseUrl}computervision/score_image');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['User-Agent'] = 'BeachBookApp/1.0'
      ..files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        filename: p.basename(imageFile.path),
        contentType: MediaType('image', 'jpeg'),
      ));

    try {
      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['results'] as List<dynamic>? ?? [];
      } else {
        throw Exception('API failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Unexpected error sending image: $e');
      throw Exception('An unexpected error occurred.');
    }
  }

  Future<Map<String, dynamic>?> getTaxonDetails(int taxonId) async {
    if (useMockData) return _getMockTaxonDetails();

    final token = await _getApiToken();
    if (token == null) return null;

    final uri = Uri.parse('${_baseUrl}taxa/$taxonId');
    try {
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['results'] is List && jsonResponse['results'].isNotEmpty) {
          return jsonResponse['results'][0];
        }
      }
    } catch (e) {
      debugPrint('Error fetching taxon details: $e');
    }
    return null;
  }
}