// lib/services/beach_data_service.dart
// UPDATED VERSION with moderation support and delete functionality

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mybeachbook/models/beach_model.dart';
import 'package:mybeachbook/models/contribution_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:dart_geohash/dart_geohash.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dart_openai/dart_openai.dart';

import 'package:mybeachbook/services/api/secrets.dart';

import 'gemini_service.dart';

class BeachDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // === MODERATION SETTINGS ===
  // Set this to true to require approval for all new beaches and contributions
  static const bool requireModeration = true;

  // === Upload user + AI image ===
  /// Upload user + AI image using Gemini
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

    // 2) Generate AI image using Gemini
    final geminiService = GeminiService();
    final geminiInfo = await geminiService.getInfoAndImage(
      'Beach Image',
      description: aiPrompt,
    );

    if (geminiInfo.imageUrl.isEmpty) {
      throw Exception('Failed to generate AI image with Gemini');
    }

    return {'user': userUrl, 'ai': geminiInfo.imageUrl};
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

  /// Add a new beach - will go to pending_beaches if moderation is enabled
  Future<String?> addBeach({
    required Beach initialBeach,
    required Contribution initialContribution,
  }) async {
    try {
      if (requireModeration) {
        // Submit to pending_beaches collection for approval
        final currentUser = FirebaseAuth.instance.currentUser;

        final pendingBeachData = initialBeach.toMap();
        pendingBeachData['submittedBy'] = currentUser?.email ?? 'anonymous';
        pendingBeachData['submittedAt'] = Timestamp.now();
        pendingBeachData['initialContribution'] = initialContribution.toMap();

        final pendingBeachRef = await _firestore
            .collection('pending_beaches')
            .add(pendingBeachData);

        print('✅ Beach submitted for approval: ${pendingBeachRef.id}');
        return pendingBeachRef.id;
      } else {
        // Original behavior - add directly to beaches
        final DocumentReference beachDocRef = await _firestore
            .collection('beaches')
            .add(initialBeach.toMap());
        await beachDocRef
            .collection('contributions')
            .add(initialContribution.toMap());
        return beachDocRef.id;
      }
    } catch (e) {
      print('Error adding new beach: $e');
      return null;
    }
  }

  /// Add a contribution to an existing beach - will go to pending_contributions if moderation is enabled
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
      final userGeohash = geoHasher.encode(userLongitude, userLatitude, precision: 9);

      if (userGeohash != beach.geohash) {
        throw Exception('You must be at the beach to make a contribution.');
      }

      if (requireModeration) {
        // Submit to pending_contributions for approval
        await beachDocRef
            .collection('pending_contributions')
            .add(contribution.toMap());
        print('✅ Contribution submitted for approval');
      } else {
        // Original behavior - add directly
        await beachDocRef
            .collection('contributions')
            .add(contribution.toMap());
      }
    } catch (e) {
      print('Error adding contribution: $e');
      rethrow;
    }
  }

  Stream<List<Beach>> getBeachesNearby({required LatLngBounds bounds}) {
    Query query = _firestore
        .collection('beaches')
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
      final DocumentSnapshot doc = await _firestore
          .collection('beaches')
          .doc(beachId)
          .get();
      if (doc.exists) {
        return Beach.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting beach by ID $beachId: $e');
      return null;
    }
  }

  /// Delete a beach and all its associated data (ADMIN ONLY)
  Future<void> deleteBeach(String beachId) async {
    try {
      final beachRef = _firestore.collection('beaches').doc(beachId);

      // 1. Get the beach data to access image URLs
      final beachDoc = await beachRef.get();
      if (!beachDoc.exists) {
        throw Exception('Beach not found');
      }

      final beach = Beach.fromFirestore(beachDoc);

      // Track which image URLs we've already deleted to avoid duplicates
      final Set<String> deletedUrls = {};

      // 2. Delete all beach images from Firebase Storage
      await _deleteBeachImages(beach.imageUrls, deletedUrls);

      // 3. Get all contributions and delete their images
      final contributionsSnapshot = await beachRef
          .collection('contributions')
          .get();

      for (final contributionDoc in contributionsSnapshot.docs) {
        final contribution = Contribution.fromFirestore(contributionDoc);
        await _deleteBeachImages(contribution.contributedImageUrls, deletedUrls);
        await contributionDoc.reference.delete();
      }

      // 4. Delete pending contributions if any
      final pendingContributionsSnapshot = await beachRef
          .collection('pending_contributions')
          .get();

      for (final pendingDoc in pendingContributionsSnapshot.docs) {
        final contribution = Contribution.fromFirestore(pendingDoc);
        await _deleteBeachImages(contribution.contributedImageUrls, deletedUrls);
        await pendingDoc.reference.delete();
      }

      // 5. Finally, delete the beach document
      await beachRef.delete();

      print('✅ Beach deleted successfully: $beachId');
      print('🗑️ Total images deleted: ${deletedUrls.length}');
    } catch (e) {
      print('❌ Error deleting beach: $e');
      rethrow;
    }
  }

  /// Delete images from Firebase Storage
  Future<void> _deleteBeachImages(List<String> imageUrls, Set<String> deletedUrls) async {
    for (final url in imageUrls) {
      // Skip if we've already deleted this URL
      if (deletedUrls.contains(url)) {
        print('⏭️ Skipping already deleted: $url');
        continue;
      }

      try {
        // Parse the storage path from the Firebase URL
        // URL format: https://firebasestorage.googleapis.com/v0/b/BUCKET/o/PATH?alt=media&token=...
        final uri = Uri.parse(url);

        // Extract the encoded path from the 'o' segment
        final pathSegments = uri.pathSegments;
        final oIndex = pathSegments.indexOf('o');

        if (oIndex == -1 || oIndex >= pathSegments.length - 1) {
          print('⚠️ Invalid Firebase Storage URL format: $url');
          continue;
        }

        // Get the encoded path and decode it
        // The path after 'o/' is URL encoded (e.g., beach_images%2Ffile.jpg)
        final encodedPath = pathSegments.sublist(oIndex + 1).join('/');
        final decodedPath = Uri.decodeComponent(encodedPath);

        print('🔍 Attempting to delete: $decodedPath');

        // Create reference and delete
        final ref = _storage.ref().child(decodedPath);
        await ref.delete();
        print('🗑️ Successfully deleted: $decodedPath');

        // Mark this URL as deleted
        deletedUrls.add(url);
      } catch (e) {
        // Continue even if image deletion fails (image might already be deleted)
        print('⚠️ Could not delete image $url: $e');
      }
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
    final path = 'beach_images/${ts}_${label}_${_uuid.v4()}.$ext';
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