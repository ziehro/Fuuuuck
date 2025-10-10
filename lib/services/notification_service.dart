// lib/services/notification_service.dart
// NEW FILE - Handles in-app notifications for pending items

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class NotificationService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _pendingBeachesCount = 0;
  int _pendingContributionsCount = 0;

  StreamSubscription? _beachesSubscription;
  StreamSubscription? _contributionsSubscription;

  bool _isInitialized = false;

  int get pendingBeachesCount => _pendingBeachesCount;
  int get pendingContributionsCount => _pendingContributionsCount;
  int get totalPendingCount => _pendingBeachesCount + _pendingContributionsCount;
  bool get hasPending => totalPendingCount > 0;

  /// Initialize real-time listeners for pending items
  void startListening() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Listen to pending beaches
    _beachesSubscription = _firestore
        .collection('pending_beaches')
        .snapshots()
        .listen((snapshot) {
      _pendingBeachesCount = snapshot.docs.length;
      notifyListeners();
    });

    // Listen to pending contributions (across all beaches)
    _contributionsSubscription = _firestore
        .collectionGroup('pending_contributions')
        .snapshots()
        .listen((snapshot) {
      _pendingContributionsCount = snapshot.docs.length;
      notifyListeners();
    });
  }

  /// Stop listening (call when user signs out)
  void stopListening() {
    _beachesSubscription?.cancel();
    _contributionsSubscription?.cancel();
    _beachesSubscription = null;
    _contributionsSubscription = null;
    _isInitialized = false;
    _pendingBeachesCount = 0;
    _pendingContributionsCount = 0;
    notifyListeners();
  }

  /// Manually refresh counts (useful for initial load)
  Future<void> refreshCounts() async {
    try {
      final beachesSnapshot = await _firestore
          .collection('pending_beaches')
          .get();
      _pendingBeachesCount = beachesSnapshot.docs.length;

      final contributionsSnapshot = await _firestore
          .collectionGroup('pending_contributions')
          .get();
      _pendingContributionsCount = contributionsSnapshot.docs.length;

      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing notification counts: $e');
    }
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}