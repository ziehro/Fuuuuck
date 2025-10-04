// lib/services/sync_service.dart
import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fuuuuck/services/beach_data_service.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BeachDataService _beachDataService = BeachDataService();
  StreamSubscription? _connectivitySubscription;

  SyncService() {
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    // Subscribe to connectivity changes
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);

    // Perform an initial check in case the app starts while already online
    final initialResult = await Connectivity().checkConnectivity();
    _handleConnectivityChange(initialResult);
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    // Check if at least one of the connectivity results is not 'none'
    if (results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi)) {
      print("Device is online. Checking for unsynced data...");
      syncPendingContributions(); // Made public
    } else {
      print("Device is offline.");
    }
  }

  // Made public so settings can call it
  Future<void> syncPendingContributions() async {
    try {
      final querySnapshot = await _firestore
          .collectionGroup('contributions')
          .where('isSynced', isEqualTo: false)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print("No unsynced contributions found.");
        return;
      }

      print("Found ${querySnapshot.docs.length} unsynced contributions. Starting sync...");

      for (final doc in querySnapshot.docs) {
        try {
          final contributionData = doc.data();
          final List<String> localPaths =
          List<String>.from(contributionData['localImagePaths'] ?? []);
          List<String> uploadedUrls = [];

          for (final path in localPaths) {
            final file = File(path);
            if (await file.exists()) {
              final url = await _beachDataService.uploadImage(file);
              if (url != null) {
                uploadedUrls.add(url);
              }
            }
          }

          // Update the document in Firestore
          await doc.reference.update({
            'contributedImageUrls': FieldValue.arrayUnion(uploadedUrls),
            'localImagePaths': [],
            'isSynced': true,
          });

          print("Successfully synced contribution ${doc.id}");
        } catch (e) {
          print("Error syncing contribution ${doc.id}: $e");
        }
      }
    } catch (e) {
      print("Error in syncPendingContributions: $e");
      rethrow;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}