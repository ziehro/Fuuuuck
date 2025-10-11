// lib/services/notification_service.dart
// FIXED VERSION - Prevents notifyListeners during disposal

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
  bool _isDisposing = false; // NEW: Track if we're disposing

  int get pendingBeachesCount => _pendingBeachesCount;
  int get pendingContributionsCount => _pendingContributionsCount;
  int get totalPendingCount => _pendingBeachesCount + _pendingContributionsCount;
  bool get hasPending => totalPendingCount > 0;
  bool get isInitialized => _isInitialized; // Add getter for external access

  /// Initialize real-time listeners for pending items
  void startListening() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Listen to pending beaches with error handling
    _beachesSubscription = _firestore
        .collection('pending_beaches')
        .snapshots()
        .listen(
          (snapshot) {
        _pendingBeachesCount = snapshot.docs.length;
        // Only notify if not disposing
        if (!_isDisposing) {
          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint('NotificationService: Error listening to pending_beaches: $error');
        _pendingBeachesCount = 0;
        if (!_isDisposing) {
          notifyListeners();
        }
      },
    );

    // Listen to pending contributions with error handling
    _contributionsSubscription = _firestore
        .collectionGroup('pending_contributions')
        .snapshots()
        .listen(
          (snapshot) {
        _pendingContributionsCount = snapshot.docs.length;
        // Only notify if not disposing
        if (!_isDisposing) {
          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint('NotificationService: Error listening to pending_contributions: $error');
        _pendingContributionsCount = 0;
        if (!_isDisposing) {
          notifyListeners();
        }
      },
    );
  }

  /// Stop listening (call when user signs out or is not admin)
  void stopListening({bool notifyChange = true}) {
    _beachesSubscription?.cancel();
    _contributionsSubscription?.cancel();
    _beachesSubscription = null;
    _contributionsSubscription = null;
    _isInitialized = false;
    _pendingBeachesCount = 0;
    _pendingContributionsCount = 0;

    // Only notify if not disposing and explicitly requested
    if (!_isDisposing && notifyChange) {
      notifyListeners();
    }
  }

  /// Manually refresh counts (useful for initial load)
  Future<void> refreshCounts() async {
    if (_isDisposing) return;

    try {
      final beachesSnapshot = await _firestore
          .collection('pending_beaches')
          .get();
      _pendingBeachesCount = beachesSnapshot.docs.length;

      final contributionsSnapshot = await _firestore
          .collectionGroup('pending_contributions')
          .get();
      _pendingContributionsCount = contributionsSnapshot.docs.length;

      if (!_isDisposing) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error refreshing notification counts: $e');
      _pendingBeachesCount = 0;
      _pendingContributionsCount = 0;
      if (!_isDisposing) {
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _isDisposing = true; // Mark as disposing before cleanup
    stopListening(notifyChange: false); // Don't notify during disposal
    super.dispose();
  }
}