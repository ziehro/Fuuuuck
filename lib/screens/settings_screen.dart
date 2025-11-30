// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mybeachbook/services/auth_service.dart';
import 'package:mybeachbook/services/settings_service.dart';
import 'package:mybeachbook/services/sync_service.dart';
import 'package:mybeachbook/main.dart';
import 'package:mybeachbook/screens/moderation_screen.dart';
import 'package:mybeachbook/services/moderation_service.dart';

import '../services/notification_service.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SyncService _syncService = SyncService();

  @override
  void initState() {
    super.initState();
    // Load settings when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SettingsService>(context, listen: false).loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final settingsService = Provider.of<SettingsService>(context);
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // User Account Section
          _buildSectionHeader('Account'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: seafoamGreen,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(user?.email ?? 'Not signed in'),
                  subtitle: Text('User ID: ${user?.uid ?? 'N/A'}'),
                ),
                ListTile(
                  leading: const Icon(Icons.email, color: seafoamGreen),
                  title: const Text('Change Email'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showChangeEmailDialog(),
                ),
                ListTile(
                  leading: const Icon(Icons.lock, color: seafoamGreen),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showChangePasswordDialog(),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: coralPink),
                  title: const Text('Delete Account'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showDeleteAccountDialog(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Map Settings Section
          _buildSectionHeader('Map Settings'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.map, color: seafoamGreen),
                  title: const Text('Map Style'),
                  subtitle: Text(_getMapStyleDisplayName(settingsService.mapStyle)),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showMapStyleDialog(settingsService),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.label, color: seafoamGreen),
                  title: const Text('Show Marker Labels'),
                  subtitle: const Text('Display beach names on map markers'),
                  value: settingsService.showMarkerLabels,
                  activeColor: seafoamGreen,
                  onChanged: (value) {
                    settingsService.setShowMarkerLabels(value);
                    if (settingsService.enableHapticFeedback) {
                      HapticFeedback.lightImpact();
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.zoom_in, color: seafoamGreen),
                  title: const Text('Default Zoom Level'),
                  subtitle: Text('${settingsService.defaultZoomLevel.toStringAsFixed(1)}x'),
                  trailing: SizedBox(
                    width: 100,
                    child: Slider(
                      value: settingsService.defaultZoomLevel,
                      min: 5.0,
                      max: 15.0,
                      divisions: 10,
                      activeColor: seafoamGreen,
                      onChanged: (value) {
                        settingsService.setDefaultZoomLevel(value);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Data & Sync Settings
          _buildSectionHeader('Data & Sync'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.sync, color: seafoamGreen),
                  title: const Text('Auto Sync'),
                  subtitle: const Text('Automatically sync data when online'),
                  value: settingsService.autoSyncEnabled,
                  activeColor: seafoamGreen,
                  onChanged: (value) {
                    settingsService.setAutoSyncEnabled(value);
                    if (settingsService.enableHapticFeedback) {
                      HapticFeedback.lightImpact();
                    }
                  },
                ),
                /*SwitchListTile(
                  secondary: const Icon(Icons.cloud_off, color: seafoamGreen),
                  title: const Text('Offline Mode'),
                  subtitle: const Text('Save data locally when offline'),
                  value: settingsService.offlineModeEnabled,
                  activeColor: seafoamGreen,
                  onChanged: (value) {
                    settingsService.setOfflineModeEnabled(value);
                    if (settingsService.enableHapticFeedback) {
                      HapticFeedback.lightImpact();
                    }
                  },
                ),*/
                ListTile(
                  leading: const Icon(Icons.cloud_upload, color: seafoamGreen),
                  title: const Text('Force Sync Now'),
                  subtitle: const Text('Upload any pending contributions'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _forceSyncData(),
                ),
                ListTile(
                  leading: const Icon(Icons.storage, color: seafoamGreen),
                  title: const Text('Clear Cache'),
                  subtitle: const Text('Free up storage space'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showClearCacheDialog(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Measurements & Units
          _buildSectionHeader('Measurements'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.straighten, color: seafoamGreen),
                  title: const Text('Distance Unit'),
                  subtitle: Text(settingsService.measurementUnit),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showMeasurementUnitDialog(settingsService),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Notifications & Feedback
          _buildSectionHeader('Notifications & Feedback'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications, color: seafoamGreen),
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Get notified about new beaches nearby'),
                  value: settingsService.notificationsEnabled,
                  activeColor: seafoamGreen,
                  onChanged: (value) {
                    settingsService.setNotificationsEnabled(value);
                    if (settingsService.enableHapticFeedback) {
                      HapticFeedback.lightImpact();
                    }
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration, color: seafoamGreen),
                  title: const Text('Haptic Feedback'),
                  subtitle: const Text('Vibrate on button presses'),
                  value: settingsService.enableHapticFeedback,
                  activeColor: seafoamGreen,
                  onChanged: (value) {
                    settingsService.setEnableHapticFeedback(value);
                    if (value) {
                      HapticFeedback.mediumImpact();
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // About & Help
          _buildSectionHeader('About & Help'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.help, color: seafoamGreen),
                  title: const Text('Help & FAQ'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showHelpDialog(),
                ),
                ListTile(
                  leading: const Icon(Icons.bug_report, color: seafoamGreen),
                  title: const Text('Report a Bug'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showBugReportDialog(),
                ),
                ListTile(
                  leading: const Icon(Icons.info, color: seafoamGreen),
                  title: const Text('About Beach Book'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showAboutDialog(),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip, color: seafoamGreen),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showPrivacyDialog(),
                ),
              ],
            ),
          ),
          _buildModerationSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: oceanBlue,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getMapStyleDisplayName(String style) {
    switch (style) {
      case 'normal':
        return 'Standard';
      case 'satellite':
        return 'Satellite';
      case 'hybrid':
        return 'Hybrid';
      case 'terrain':
        return 'Terrain';
      default:
        return 'Standard';
    }
  }

  // Dialog methods
  void _showChangeEmailDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'New Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Current Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) throw Exception('Not signed in');

                // Re-authenticate
                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: passwordController.text,
                );
                await user.reauthenticateWithCredential(credential);

                // Update email
                await user.verifyBeforeUpdateEmail(emailController.text);

                Navigator.pop(context);
                _showSnackBar('Verification email sent. Please check your inbox.');
              } catch (e) {
                _showSnackBar('Failed to change email: ${e.toString()}');
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              decoration: const InputDecoration(labelText: 'Current Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              decoration: const InputDecoration(labelText: 'New Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordController,
              decoration: const InputDecoration(labelText: 'Confirm New Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (newPasswordController.text != confirmPasswordController.text) {
                _showSnackBar('New passwords do not match');
                return;
              }

              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) throw Exception('Not signed in');

                // Re-authenticate
                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: currentPasswordController.text,
                );
                await user.reauthenticateWithCredential(credential);

                // Update password
                await user.updatePassword(newPasswordController.text);

                Navigator.pop(context);
                _showSnackBar('Password updated successfully');
              } catch (e) {
                _showSnackBar('Failed to change password: ${e.toString()}');
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to permanently delete your account? This action cannot be undone.',
              style: TextStyle(color: coralPink),
            ),
            const SizedBox(height: 16),
            const Text('All your contributions and data will be removed.'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Enter your password to confirm'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) throw Exception('Not signed in');

                // Re-authenticate
                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: passwordController.text,
                );
                await user.reauthenticateWithCredential(credential);

                // Delete user contributions from Firestore
                final contributions = await FirebaseFirestore.instance
                    .collectionGroup('contributions')
                    .where('userId', isEqualTo: user.uid)
                    .get();

                for (var doc in contributions.docs) {
                  await doc.reference.delete();
                }

                // Delete user account
                await user.delete();

                Navigator.pop(context);
                Navigator.pop(context); // Return to auth screen
                _showSnackBar('Account deleted successfully');
              } catch (e) {
                _showSnackBar('Failed to delete account: ${e.toString()}');
              }
            },
            style: TextButton.styleFrom(foregroundColor: coralPink),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  void _showMapStyleDialog(SettingsService settingsService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Map Style'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['normal', 'satellite', 'hybrid', 'terrain'].map((style) {
            return RadioListTile<String>(
              title: Text(_getMapStyleDisplayName(style)),
              value: style,
              groupValue: settingsService.mapStyle,
              onChanged: (value) {
                settingsService.setMapStyle(value!);
                if (settingsService.enableHapticFeedback) {
                  HapticFeedback.selectionClick();
                }
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showMeasurementUnitDialog(SettingsService settingsService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Distance Unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Steps', 'Meters', 'Feet'].map((unit) {
            return RadioListTile<String>(
              title: Text(unit),
              value: unit,
              groupValue: settingsService.measurementUnit,
              onChanged: (value) {
                settingsService.setMeasurementUnit(value!);
                if (settingsService.enableHapticFeedback) {
                  HapticFeedback.selectionClick();
                }
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear all cached data including offline maps and images. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _showSnackBar('Clearing cache...');

              await Provider.of<SettingsService>(context, listen: false).clearCache();

              _showSnackBar('Cache cleared successfully');
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & FAQ'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('How to add a beach:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('1. Tap the + button on the map\n2. Fill out the form\n3. Take photos\n4. Save your contribution'),
              SizedBox(height: 16),
              Text('How to use heatmap layers:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Tap the layers button in the top bar and select a metric to visualize on the map. Markers will hide automatically.'),
              SizedBox(height: 16),
              Text('How to scan flora/fauna:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Use the scanner tab to identify plants and animals with your camera.'),
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

  void _showBugReportDialog() {
    final bugController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report a Bug'),
        content: TextField(
          controller: bugController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Describe the issue you encountered...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (bugController.text.trim().isEmpty) {
                _showSnackBar('Please describe the issue');
                return;
              }

              try {
                final user = FirebaseAuth.instance.currentUser;
                await FirebaseFirestore.instance.collection('bug_reports').add({
                  'userId': user?.uid ?? 'anonymous',
                  'userEmail': user?.email ?? 'anonymous',
                  'description': bugController.text.trim(),
                  'timestamp': Timestamp.now(),
                });

                Navigator.pop(context);
                _showSnackBar('Bug report sent. Thank you!');
              } catch (e) {
                _showSnackBar('Failed to send report: ${e.toString()}');
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => const AboutDialog(
        applicationName: 'Beach Book',
        applicationVersion: '1.0.0',
        applicationIcon: Icon(Icons.beach_access, size: 64, color: seafoamGreen),
        children: [
          Text('Beach Book helps you discover, document, and share beautiful beaches.'),
          SizedBox(height: 16),
          Text('Built with Flutter and Firebase.'),
          SizedBox(height: 16),
          Text('© 2025 Beach Book. All rights reserved.'),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Your privacy is important to us. Beach Book collects location data and photos only with your permission to help build our beach database.\n\n'
                'We do not share personal information with third parties.\n\n'
                'All data is stored securely using Firebase.\n\n'
                'You can delete your account and all associated data at any time from the Settings screen.',
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

  void _forceSyncData() async {
    _showSnackBar('Syncing data...');
    try {
      await _syncService.syncPendingContributions();
      if (mounted) _showSnackBar('Sync completed successfully');
    } catch (e) {
      if (mounted) _showSnackBar('Sync failed: ${e.toString()}');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // Add this to your existing lib/screens/settings_screen.dart
// This replaces the _buildModerationSection() method

  Widget _buildModerationSection() {
    // Only show for admin users
    final adminUserIds = ['t8xTPHecHIRY8nWcvmQBzWouBIh1']; // Replace with your Firebase Auth UID
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null || !adminUserIds.contains(currentUser.uid)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        _buildSectionHeader('Admin'),
        Card(
          child: Column(
            children: [
              // Use Consumer to get live updates
              Consumer<NotificationService>(
                builder: (context, notificationService, child) {
                  final beachesCount = notificationService.pendingBeachesCount;
                  final contributionsCount = notificationService.pendingContributionsCount;
                  final totalCount = notificationService.totalPendingCount;

                  return ListTile(
                    leading: Stack(
                      children: [
                        const Icon(Icons.admin_panel_settings, color: seafoamGreen),
                        if (totalCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                totalCount > 9 ? '9+' : totalCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: const Text('Moderation Queue'),
                    subtitle: totalCount == 0
                        ? const Text(
                      'No pending items',
                      style: TextStyle(color: Colors.green),
                    )
                        : Text(
                      '$totalCount pending ($beachesCount beaches, $contributionsCount contributions)',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (totalCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              totalCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ModerationScreen(),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

}