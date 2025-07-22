// lib/services/api/inaturalist_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class INaturalistService {
  // ** FIX: Updated the API endpoint URL **
  static const String _baseUrl = 'https://api.inaturalist.org/v2/';

  Future<List<dynamic>> identifyImage(File imageFile) async {
    // ** FIX: Changed the endpoint path to 'computervision/score_image' **
    final uri = Uri.parse('${_baseUrl}computervision/score_image');

    final request = http.MultipartRequest('POST', uri);

    request.headers['User-Agent'] = 'BeachBookApp/1.0';

    request.files.add(
      await http.MultipartFile.fromPath(
        'image', // ** FIX: Changed the field name from 'file' to 'image' **
        imageFile.path,
        filename: p.basename(imageFile.path),
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    try {
      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse != null && jsonResponse['results'] is List) {
          return jsonResponse['results'];
        }
        return [];
      } else {
        debugPrint('iNaturalist API Error: Status ${response.statusCode}, Body: ${response.body}');
        throw Exception('iNaturalist API failed: ${response.statusCode} ${response.body}');
      }
    } on SocketException {
      debugPrint('Network error during iNaturalist API call: No Internet connection.');
      throw Exception('Network error. Please check your internet connection.');
    } catch (e) {
      debugPrint('Unexpected error sending image to iNaturalist: $e');
      throw Exception('An unexpected error occurred during identification.');
    }
  }

  Future<Map<String, dynamic>?> getTaxonDetails(int taxonId) async {
    final uri = Uri.parse('${_baseUrl}taxa/$taxonId');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        // The v2 API has a slightly different response structure
        if (jsonResponse != null && jsonResponse['results'] is List && jsonResponse['results'].isNotEmpty) {
          final taxonData = jsonResponse['results'][0];
          // Extract the Wikipedia summary from the taxon data
          final wikipediaSummary = taxonData['wikipedia_summary'];
          return {'wikipedia_summary': wikipediaSummary};
        }
      } else {
        debugPrint('Failed to fetch taxon details: ${response.statusCode} - ${response.body}');
      }
      return null;
    } catch (e) {
      debugPrint('Unexpected error fetching taxon details: $e');
      return null;
    }
  }
}