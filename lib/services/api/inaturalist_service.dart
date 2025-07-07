// lib/services/api/inaturalist_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart'; // Provides debugPrint

class INaturalistService {
  static const String _baseUrl = 'https://api.inaturalist.org/v1/';

  Future<List<dynamic>> identifyImage(File imageFile) async {
    final uri = Uri.parse('${_baseUrl}identifications/suggestions');

    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        filename: p.basename(imageFile.path),
        contentType: MediaType('image', 'jpeg'), // Ensure this matches your saved image type (e.g., .jpg)
      ),
    );

    try {
      // Send the request and add a timeout
      final streamedResponse = await request.send().timeout(const Duration(seconds: 60)); // 30-second timeout
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse != null && jsonResponse['results'] is List) {
          return jsonResponse['results'];
        }
        return [];
      } else {
        // More specific error for debugging
        debugPrint('iNaturalist API Error: Status ${response.statusCode}, Body: ${response.body}');
        throw Exception('iNaturalist API failed: ${response.statusCode} ${response.body}');
      }
    } on SocketException {
      debugPrint('Network error during iNaturalist API call: No Internet connection or server unreachable.');
      throw Exception('Network error. Please check your internet connection.');
    } on http.ClientException catch (e) {
      debugPrint('HTTP Client error during iNaturalist API call: $e');
      throw Exception('Request failed: ${e.message}');
    } on FormatException catch (e) {
      debugPrint('JSON parsing error from iNaturalist API: $e');
      throw Exception('Received invalid data from server.');
    } catch (e) {
      debugPrint('Unexpected error sending image to iNaturalist: $e');
      throw Exception('An unexpected error occurred during identification.');
    }
  }

  Future<Map<String, dynamic>?> getTaxonDetails(int taxonId) async {
    final uri = Uri.parse('${_baseUrl}taxa/$taxonId');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 60)); // Add timeout here too
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse != null && jsonResponse['results'] is List && jsonResponse['results'].isNotEmpty) {
          return jsonResponse['results'][0];
        }
      } else {
        debugPrint('Failed to fetch taxon details: ${response.statusCode} - ${response.body}');
      }
      return null;
    } on SocketException {
      debugPrint('Network error fetching taxon details: No Internet connection.');
      return null;
    } on http.ClientException catch (e) {
      debugPrint('HTTP Client error fetching taxon details: $e');
      return null;
    } on FormatException catch (e) {
      debugPrint('JSON parsing error for taxon details: $e');
      return null;
    } catch (e) {
      debugPrint('Unexpected error fetching taxon details: $e');
      return null;
    }
  }
}