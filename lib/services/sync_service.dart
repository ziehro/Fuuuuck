// lib/services/sync_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _connectivitySubscription;

  SyncService() {
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);

    final initialResult = await Connectivity().checkConnectivity();
    _handleConnectivityChange(initialResult);
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi)) {
      print("Device is online. Checking for unsynced data...");
      // With moderation enabled, we don't need offline sync
      // Users must be online to submit contributions
    } else {
      print("Device is offline.");
    }
  }

  // Simplified - no longer tries to sync unsynced contributions
  Future<void> syncPendingContributions() async {
    // With moderation, contributions go directly to pending_contributions
    // when online. No offline queue needed.
    print("Sync not needed with moderation workflow.");
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}