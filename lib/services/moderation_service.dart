// lib/services/moderation_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mybeachbook/models/beach_model.dart';
import 'package:mybeachbook/models/contribution_model.dart';

class ModerationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Approve a pending beach and move it to the main beaches collection
  Future<void> approveBeach(String pendingBeachId, Map<String, dynamic> data) async {
    try {
      // Extract the initial contribution data
      final initialContributionData = data['initialContribution'] as Map<String, dynamic>?;

      // Remove the initial contribution from beach data before saving
      final beachData = Map<String, dynamic>.from(data);
      beachData.remove('initialContribution');
      beachData.remove('submittedBy');
      beachData.remove('submittedAt');

      // Use a batch to ensure atomicity
      final batch = _firestore.batch();

      // 1. Add the beach to the main beaches collection
      final beachRef = _firestore.collection('beaches').doc();
      batch.set(beachRef, beachData);

      // 2. Add the initial contribution as a subcollection
      if (initialContributionData != null) {
        final contributionRef = beachRef.collection('contributions').doc();
        batch.set(contributionRef, initialContributionData);
      }

      // 3. Delete the pending beach
      final pendingBeachRef = _firestore.collection('pending_beaches').doc(pendingBeachId);
      batch.delete(pendingBeachRef);

      // Commit all changes
      await batch.commit();

      print('✅ Beach approved and moved to main collection: ${beachRef.id}');
    } catch (e) {
      print('❌ Error approving beach: $e');
      rethrow;
    }
  }

  /// Reject a pending beach
  Future<void> rejectBeach(String pendingBeachId) async {
    try {
      await _firestore.collection('pending_beaches').doc(pendingBeachId).delete();
      print('🗑️ Pending beach rejected: $pendingBeachId');
    } catch (e) {
      print('❌ Error rejecting beach: $e');
      rethrow;
    }
  }

  /// Approve a pending contribution and move it to the beach's contributions
  Future<void> approveContribution(
      String beachId, String contributionId, Map<String, dynamic> data) async {
    try {
      final batch = _firestore.batch();

      // 1. Add the contribution to the beach's contributions subcollection
      final contributionRef = _firestore
          .collection('beaches')
          .doc(beachId)
          .collection('contributions')
          .doc();
      batch.set(contributionRef, data);

      // 2. Delete the pending contribution
      final pendingContributionRef = _firestore
          .collection('beaches')
          .doc(beachId)
          .collection('pending_contributions')
          .doc(contributionId);
      batch.delete(pendingContributionRef);

      await batch.commit();

      print('✅ Contribution approved: $contributionId');
    } catch (e) {
      print('❌ Error approving contribution: $e');
      rethrow;
    }
  }

  /// Reject a pending contribution
  Future<void> rejectContribution(String beachId, String contributionId) async {
    try {
      await _firestore
          .collection('beaches')
          .doc(beachId)
          .collection('pending_contributions')
          .doc(contributionId)
          .delete();
      print('🗑️ Pending contribution rejected: $contributionId');
    } catch (e) {
      print('❌ Error rejecting contribution: $e');
      rethrow;
    }
  }

  /// Submit a name change suggestion
  Future<void> submitNameChangeSuggestion({
    required String beachId,
    required String currentName,
    required String suggestedName,
    required String userId,
    required String userEmail,
  }) async {
    try {
      await _firestore.collection('pending_name_changes').add({
        'beachId': beachId,
        'currentName': currentName,
        'suggestedName': suggestedName,
        'userId': userId,
        'userEmail': userEmail,
        'submittedAt': Timestamp.now(),
        'status': 'pending',
      });
      print('✅ Name change suggestion submitted');
    } catch (e) {
      print('❌ Error submitting name change: $e');
      rethrow;
    }
  }

  /// Approve a name change suggestion
  Future<void> approveNameChange(String suggestionId, String beachId, String newName) async {
    try {
      final batch = _firestore.batch();

      // Update the beach name
      final beachRef = _firestore.collection('beaches').doc(beachId);
      batch.update(beachRef, {'name': newName});

      // Delete the suggestion
      final suggestionRef = _firestore.collection('pending_name_changes').doc(suggestionId);
      batch.delete(suggestionRef);

      await batch.commit();
      print('✅ Name change approved and applied: $newName');
    } catch (e) {
      print('❌ Error approving name change: $e');
      rethrow;
    }
  }

  /// Reject a name change suggestion
  Future<void> rejectNameChange(String suggestionId) async {
    try {
      await _firestore.collection('pending_name_changes').doc(suggestionId).delete();
      print('🗑️ Name change suggestion rejected: $suggestionId');
    } catch (e) {
      print('❌ Error rejecting name change: $e');
      rethrow;
    }
  }

  /// Get count of pending items
  Future<Map<String, int>> getPendingCounts() async {
    try {
      final pendingBeachesCount = (await _firestore.collection('pending_beaches').get()).docs.length;
      final pendingContributionsCount = (await _firestore.collectionGroup('pending_contributions').get()).docs.length;
      final pendingNameChangesCount = (await _firestore.collection('pending_name_changes').get()).docs.length;

      return {
        'beaches': pendingBeachesCount,
        'contributions': pendingContributionsCount,
        'nameChanges': pendingNameChangesCount,
      };
    } catch (e) {
      print('Error getting pending counts: $e');
      return {'beaches': 0, 'contributions': 0, 'nameChanges': 0};
    }
  }
}