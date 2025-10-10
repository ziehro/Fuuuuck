// lib/screens/moderation_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mybeachbook/models/beach_model.dart';
import 'package:mybeachbook/models/contribution_model.dart';
import 'package:mybeachbook/services/moderation_service.dart';
import 'package:mybeachbook/main.dart';

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ModerationService _moderationService = ModerationService();

  // Admin user IDs (add your Firebase Auth UID here)
  static const List<String> _adminUserIds = [
    'c4So8SbUIpYPsV0bF0aaAtyWj9q1', // Replace with your actual Firebase Auth UID
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAdminAccess();
  }

  void _checkAdminAccess() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || !_adminUserIds.contains(currentUser.uid)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSnackBar('You do not have admin access');
        Navigator.pop(context);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderation Queue'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending Beaches', icon: Icon(Icons.add_location)),
            Tab(text: 'Pending Contributions', icon: Icon(Icons.edit_location)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingBeachesList(),
          _buildPendingContributionsList(),
        ],
      ),
    );
  }

  Widget _buildPendingBeachesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pending_beaches')
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text('No pending beaches to review!'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildPendingBeachCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildPendingContributionsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('pending_contributions')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text('No pending contributions to review!'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            // Extract beach ID from the document reference path
            final pathSegments = doc.reference.path.split('/');
            final beachId = pathSegments[pathSegments.indexOf('beaches') + 1];
            return _buildPendingContributionCard(beachId, doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildPendingBeachCard(String pendingBeachId, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Unnamed Beach';
    final description = data['description'] ?? '';
    final submittedBy = data['submittedBy'] ?? 'Unknown';
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
    final imageUrls = List<String>.from(data['imageUrls'] ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrls.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                imageUrls.first,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, size: 64),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (description.isNotEmpty) ...[
                  Text(description, maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Submitted by: $submittedBy',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                if (submittedAt != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateTime(submittedAt),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approveBeach(pendingBeachId, data),
                        icon: const Icon(Icons.check),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _rejectBeach(pendingBeachId),
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _viewBeachDetails(data),
                      icon: const Icon(Icons.info_outline),
                      tooltip: 'View Details',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingContributionCard(
      String beachId, String contributionId, Map<String, dynamic> data) {
    final userEmail = data['userEmail'] ?? 'Unknown';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final imageUrls = List<String>.from(data['contributedImageUrls'] ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrls.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                imageUrls.first,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 150,
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, size: 48),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('beaches')
                      .doc(beachId)
                      .get(),
                  builder: (context, snapshot) {
                    final beachName = snapshot.hasData
                        ? (snapshot.data!.data() as Map<String, dynamic>)['name']
                        : 'Loading...';
                    return Text(
                      'Contribution to: $beachName',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'By: $userEmail',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                if (timestamp != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateTime(timestamp),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _approveContribution(beachId, contributionId, data),
                        icon: const Icon(Icons.check),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _rejectContribution(beachId, contributionId),
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _viewContributionDetails(data),
                      icon: const Icon(Icons.info_outline),
                      tooltip: 'View Details',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveBeach(String pendingBeachId, Map<String, dynamic> data) async {
    try {
      _showSnackBar('Approving beach...');
      await _moderationService.approveBeach(pendingBeachId, data);
      _showSnackBar('Beach approved successfully!');
    } catch (e) {
      _showSnackBar('Error approving beach: $e');
    }
  }

  Future<void> _rejectBeach(String pendingBeachId) async {
    final confirmed = await _showConfirmDialog(
      'Reject Beach',
      'Are you sure you want to reject this beach submission?',
    );

    if (confirmed == true) {
      try {
        await _moderationService.rejectBeach(pendingBeachId);
        _showSnackBar('Beach rejected');
      } catch (e) {
        _showSnackBar('Error rejecting beach: $e');
      }
    }
  }

  Future<void> _approveContribution(
      String beachId, String contributionId, Map<String, dynamic> data) async {
    try {
      _showSnackBar('Approving contribution...');
      await _moderationService.approveContribution(beachId, contributionId, data);
      _showSnackBar('Contribution approved successfully!');
    } catch (e) {
      _showSnackBar('Error approving contribution: $e');
    }
  }

  Future<void> _rejectContribution(String beachId, String contributionId) async {
    final confirmed = await _showConfirmDialog(
      'Reject Contribution',
      'Are you sure you want to reject this contribution?',
    );

    if (confirmed == true) {
      try {
        await _moderationService.rejectContribution(beachId, contributionId);
        _showSnackBar('Contribution rejected');
      } catch (e) {
        _showSnackBar('Error rejecting contribution: $e');
      }
    }
  }

  void _viewBeachDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['name'] ?? 'Beach Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Country', data['country']),
              _buildDetailRow('Province', data['province']),
              _buildDetailRow('Municipality', data['municipality']),
              _buildDetailRow('Description', data['description']),
              _buildDetailRow('Latitude', data['latitude']?.toString()),
              _buildDetailRow('Longitude', data['longitude']?.toString()),
              const SizedBox(height: 8),
              const Text('User Answers:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...((data['initialContribution']?['userAnswers'] as Map<String, dynamic>?) ?? {})
                  .entries
                  .map((e) => _buildDetailRow(e.key, e.value.toString())),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _viewContributionDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contribution Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('User Email', data['userEmail']),
              _buildDetailRow('Latitude', data['latitude']?.toString()),
              _buildDetailRow('Longitude', data['longitude']?.toString()),
              const SizedBox(height: 8),
              const Text('User Answers:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...((data['userAnswers'] as Map<String, dynamic>?) ?? {})
                  .entries
                  .map((e) => _buildDetailRow(e.key, e.value.toString())),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}