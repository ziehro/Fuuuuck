// lib/services/beach_data_service.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fuuuuck/models/beach_model.dart';
import 'package:fuuuuck/models/contribution_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:dart_geohash/dart_geohash.dart';

class BeachDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  Future<String?> uploadImage(File imageFile) async {
    try {
      final String fileName = 'beach_images/${_uuid.v4()}.jpg';
      final Reference storageRef = _storage.ref().child(fileName);
      final UploadTask uploadTask = storageRef.putFile(imageFile);

      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
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
      final userGeohash = geoHasher.encode(userLongitude, userLatitude, precision: 9);

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
    // Query for beaches within the latitude and longitude bounds of the visible map area.
    Query query = _firestore.collection('beaches')
        .where('latitude', isGreaterThan: bounds.southwest.latitude)
        .where('latitude', isLessThan: bounds.northeast.latitude);

    return query.snapshots().map((snapshot) {
      // Since Firestore can't query two different fields with range filters,
      // we do the longitude filtering on the client side.
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
}