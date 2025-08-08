// lib/services/beach_data_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fuuuuck/models/beach_model.dart';
import 'package:fuuuuck/models/contribution_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:dart_geohash/dart_geohash.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dart_openai/dart_openai.dart';

import 'package:fuuuuck/services/api/secrets.dart'; // openAIApiKey

class BeachDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // === New: upload user + AI image to the same Storage folder using putFile ===
  Future<Map<String, String>> uploadUserAndAiImages({
    required String beachId,
    required File userImageFile,
    required String aiPrompt,
  }) async {
    // 1) Upload the user image first
    final userUrl = await _uploadFileToBeachFolder(
      beachId: beachId,
      file: userImageFile,
      ext: _extFromPath(userImageFile.path) ?? 'jpg',
      label: 'user',
    );

    // 2) Generate AI image → save to temp → upload via same putFile path
    OpenAI.apiKey = openAIApiKey;
    final result = await OpenAI.instance.image.create(
      model: 'dall-e-3',
      prompt: aiPrompt,
      n: 1,
      size: OpenAIImageSize.size1024,
      // NOTE: no responseFormat here – some server versions reject it
    );

// Get the image URL from OpenAI
    final openAiUrl = result.data.first.url;
    if (openAiUrl == null || openAiUrl.isEmpty) {
      throw Exception('OpenAI returned no image URL.');
    }

// Download the image to bytes
    final resp = await http.get(Uri.parse(openAiUrl));
    if (resp.statusCode != 200) {
      throw Exception('Failed to download OpenAI image: HTTP ${resp.statusCode}');
    }
    final bytes = resp.bodyBytes;

// Write to a temp file
    final dir = await getTemporaryDirectory();
    final aiFile = File('${dir.path}/ai_${_uuid.v4()}.png');
    await aiFile.writeAsBytes(bytes, flush: true);

// Upload with your existing putFile path (same folder as user photos)
    final aiUrl = await _uploadFileToBeachFolder(
      beachId: beachId,
      file: aiFile,
      ext: 'png',
      label: 'ai',
    );

    return {'user': userUrl, 'ai': aiUrl};
  }

  Future<String?> uploadImage(File imageFile) async {
    try {
      final String fileName = 'beach_images/${_uuid.v4()}.jpg';
      final Reference storageRef = _storage.ref().child(fileName);
      final UploadTask uploadTask = storageRef.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<List<String>> uploadImages(List<String> imagePaths) async {
    final List<String> imageUrls = [];
    for (String path in imagePaths) {
      final imageUrl = await uploadImage(File(path));
      if (imageUrl != null) {
        imageUrls.add(imageUrl);
      }
    }
    return imageUrls;
  }

  Future<String?> addBeach({
    required Beach initialBeach,
    required Contribution initialContribution,
  }) async {
    try {
      final DocumentReference beachDocRef = await _firestore.collection('beaches').add(initialBeach.toMap());
      await beachDocRef.collection('contributions').add(initialContribution.toMap());
      return beachDocRef.id;
    } catch (e) {
      print('Error adding new beach: $e');
      return null;
    }
  }

  Future<void> addContribution({
    required String beachId,
    required Contribution contribution,
    required double? userLatitude,
    required double? userLongitude,
  }) async {
    if (userLatitude == null || userLongitude == null) {
      throw Exception('Could not determine user location.');
    }

    try {
      final DocumentReference beachDocRef = _firestore.collection('beaches').doc(beachId);
      final beachSnapshot = await beachDocRef.get();

      if (!beachSnapshot.exists) {
        throw Exception('Beach not found.');
      }

      final beach = Beach.fromFirestore(beachSnapshot);
      final geoHasher = GeoHasher();
      final userGeohash = geoHasher.encode(userLongitude, userLatitude, precision: 9); // (lat, lon)

      if (userGeohash != beach.geohash) {
        throw Exception('You must be at the beach to make a contribution.');
      }

      await beachDocRef.collection('contributions').add(contribution.toMap());
    } catch (e) {
      print('Error adding contribution: $e');
      rethrow;
    }
  }

  Stream<List<Beach>> getBeachesNearby({required LatLngBounds bounds}) {
    Query query = _firestore.collection('beaches')
        .where('latitude', isGreaterThan: bounds.southwest.latitude)
        .where('latitude', isLessThan: bounds.northeast.latitude);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Beach.fromFirestore(doc))
          .where((beach) =>
      beach.longitude > bounds.southwest.longitude &&
          beach.longitude < bounds.northeast.longitude)
          .toList();
    });
  }

  Future<Beach?> getBeachById(String beachId) async {
    try {
      final DocumentSnapshot doc = await _firestore.collection('beaches').doc(beachId).get();
      if (doc.exists) {
        return Beach.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting beach by ID $beachId: $e');
      return null;
    }
  }

  // === helpers ===

  Future<String> _uploadFileToBeachFolder({
    required String beachId,
    required File file,
    required String ext,
    required String label,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'beach_images/${ts}_${label}_${_uuid.v4()}.$ext'; // same folder/pattern as user flow
    final ref = _storage.ref().child(path);
    final metadata = SettableMetadata(
      contentType: _contentTypeForExt(ext),
      customMetadata: {'label': label, 'beachId': beachId},
    );
    final snap = await ref.putFile(file, metadata);
    return await snap.ref.getDownloadURL();
  }

  String _contentTypeForExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  String? _extFromPath(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return null;
    return path.substring(dot + 1);
  }
}
