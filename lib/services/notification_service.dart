// lib/services/notification_service.dart
// UPDATED VERSION - Added name change tracking

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class NotificationService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _pendingBeachesCount = 0;
  int _pendingContributionsCount = 0;
  int _pendingNameChangesCount = 0;

  StreamSubscription? _beachesSubscription;
  StreamSubscription? _contributionsSubscription;
  StreamSubscription? _nameChangesSubscription;

  bool _isInitialized = false;
  bool _isDisposing = false;

  int get pendingBeachesCount => _pendingBeachesCount;
  int get pendingContributionsCount => _pendingContributionsCount;
  int get pendingNameChangesCount => _pendingNameChangesCount;
  int get totalPendingCount => _pendingBeachesCount + _pendingContributionsCount + _pendingNameChangesCount;
  bool get hasPending => totalPendingCount > 0;
  bool get isInitialized => _isInitialized;

  /// Initialize real-time listeners for pending items
  void startListening() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Listen to pending beaches
    _beachesSubscription = _firestore
        .collection('pending_beaches')
        .snapshots()
        .listen(
          (snapshot) {
        _pendingBeachesCount = snapshot.docs.length;
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

    // Listen to pending contributions
    _contributionsSubscription = _firestore
        .collectionGroup('pending_contributions')
        .snapshots()
        .listen(
          (snapshot) {
        _pendingContributionsCount = snapshot.docs.length;
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

    // Listen to pending name changes
    _nameChangesSubscription = _firestore
        .collection('pending_name_changes')
        .snapshots()
        .listen(
          (snapshot) {
        _pendingNameChangesCount = snapshot.docs.length;
        if (!_isDisposing) {
          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint('NotificationService: Error listening to pending_name_changes: $error');
        _pendingNameChangesCount = 0;
        if (!_isDisposing) {
          notifyListeners();
        }
      },
    );
  }

  /// Stop listening
  void stopListening({bool notifyChange = true}) {
    _beachesSubscription?.cancel();
    _contributionsSubscription?.cancel();
    _nameChangesSubscription?.cancel();
    _beachesSubscription = null;
    _contributionsSubscription = null;
    _nameChangesSubscription = null;
    _isInitialized = false;
    _pendingBeachesCount = 0;
    _pendingContributionsCount = 0;
    _pendingNameChangesCount = 0;

    if (!_isDisposing && notifyChange) {
      notifyListeners();
    }
  }

  /// Manually refresh counts
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

      final nameChangesSnapshot = await _firestore
          .collection('pending_name_changes')
          .get();
      _pendingNameChangesCount = nameChangesSnapshot.docs.length;

      if (!_isDisposing) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error refreshing notification counts: $e');
      _pendingBeachesCount = 0;
      _pendingContributionsCount = 0;
      _pendingNameChangesCount = 0;
      if (!_isDisposing) {
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _isDisposing = true;
    stopListening(notifyChange: false);
    super.dispose();
  }
}