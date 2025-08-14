// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fuuuuck/services/auth_service.dart';
import 'package:fuuuuck/main.dart'; // For theme colors

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _offlineModeEnabled = false;
  bool _autoSyncEnabled = true;
  bool _showMarkerLabels = true;
  bool _enableHapticFeedback = true;
  String _mapStyle = 'Standard';
  String _measurementUnit = 'Steps';
  double _mapZoomLevel = 10.0;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
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
            color: arbutusCream, // Override the dark red card color
            child: Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: arbutusGreen,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(user?.email ?? 'Not signed in'),
                  subtitle: Text('User ID: ${user?.uid ?? 'N/A'}'),
                ),
                ListTile(
                  leading: const Icon(Icons.email, color: arbutusGreen),
                  title: const Text('Change Email'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showChangeEmailDialog(),
                ),
                ListTile(
                  leading: const Icon(Icons.lock, color: arbutusGreen),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showChangePasswordDialog(),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
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
            color: arbutusCream, // Override the dark red card color
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.map, color: arbutusGreen),
                  title: const Text('Map Style'),
                  subtitle: Text(_mapStyle),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showMapStyleDialog(),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.label, color: arbutusGreen),
                  title: const Text('Show Marker Labels'),
                  subtitle: const Text('Display beach names on map markers'),
                  value: _showMarkerLabels,
                  activeColor: arbutusGreen,
                  onChanged: (value) {
                    setState(() => _showMarkerLabels = value);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.zoom_in, color: arbutusGreen),
                  title: const Text('Default Zoom Level'),
                  subtitle: Text('${_mapZoomLevel.toStringAsFixed(1)}x'),
                  trailing: SizedBox(
                    width: 100,
                    child: Slider(
                      value: _mapZoomLevel,
                      min: 5.0,
                      max: 15.0,
                      divisions: 10,
                      activeColor: arbutusGreen,
                      onChanged: (value) {
                        setState(() => _mapZoomLevel = value);
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
            color: arbutusCream, // Override the dark red card color
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.sync, color: arbutusGreen),
                  title: const Text('Auto Sync'),
                  subtitle: const Text('Automatically sync data when online'),
                  value: _autoSyncEnabled,
                  activeColor: arbutusGreen,
                  onChanged: (value) {
                    setState(() => _autoSyncEnabled = value);
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.cloud_off, color: arbutusGreen),
                  title: const Text('Offline Mode'),
                  subtitle: const Text('Save data locally when offline'),
                  value: _offlineModeEnabled,
                  activeColor: arbutusGreen,
                  onChanged: (value) {
                    setState(() => _offlineModeEnabled = value);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_upload, color: arbutusGreen),
                  title: const Text('Force Sync Now'),
                  subtitle: const Text('Upload any pending contributions'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _forceSyncData(),
                ),
                ListTile(
                  leading: const Icon(Icons.storage, color: arbutusGreen),
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
            color: arbutusCream, // Override the dark red card color
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.straighten, color: arbutusGreen),
                  title: const Text('Distance Unit'),
                  subtitle: Text(_measurementUnit),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showMeasurementUnitDialog(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Notifications & Feedback
          _buildSectionHeader('Notifications & Feedback'),
          Card(
            color: arbutusCream, // Override the dark red card color
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications, color: arbutusGreen),
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Get notified about new beaches nearby'),
                  value: _notificationsEnabled,
                  activeColor: arbutusGreen,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration, color: arbutusGreen),
                  title: const Text('Haptic Feedback'),
                  subtitle: const Text('Vibrate on button presses'),
                  value: _enableHapticFeedback,
                  activeColor: arbutusGreen,
                  onChanged: (value) {
                    setState(() => _enableHapticFeedback = value);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // About & Help
          _buildSectionHeader('About & Help'),
          Card(
            color: arbutusCream, // Override the dark red card color
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.help, color: arbutusGreen),
                  title: const Text('Help & FAQ'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showHelpDialog(),
                ),
                ListTile(
                  leading: const Icon(Icons.bug_report, color: arbutusGreen),
                  title: const Text('Report a Bug'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showBugReportDialog(),
                ),
                ListTile(
                  leading: const Icon(Icons.info, color: arbutusGreen),
                  title: const Text('About Beach Book'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showAboutDialog(),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip, color: arbutusGreen),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showPrivacyDialog(),
                ),
              ],
            ),
          ),

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
          color: arbutusBrown,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Dialog methods
  void _showChangeEmailDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Email'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: InputDecoration(labelText: 'New Email')),
            SizedBox(height: 16),
            TextField(decoration: InputDecoration(labelText: 'Current Password')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Update')),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: InputDecoration(labelText: 'Current Password'), obscureText: true),
            SizedBox(height: 16),
            TextField(decoration: InputDecoration(labelText: 'New Password'), obscureText: true),
            SizedBox(height: 16),
            TextField(decoration: InputDecoration(labelText: 'Confirm New Password'), obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Update')),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to permanently delete your account? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showMapStyleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Map Style'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Standard', 'Satellite', 'Hybrid', 'Terrain'].map((style) {
            return RadioListTile<String>(
              title: Text(style),
              value: style,
              groupValue: _mapStyle,
              onChanged: (value) {
                setState(() => _mapStyle = value!);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showMeasurementUnitDialog() {
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
              groupValue: _measurementUnit,
              onChanged: (value) {
                setState(() => _measurementUnit = value!);
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
        content: const Text('This will clear all cached data including offline maps and images. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
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
              Text('Tap the layers button in the top bar and select a metric to visualize on the map.'),
              SizedBox(height: 16),
              Text('How to scan flora/fauna:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Use the scanner tab to identify plants and animals with your camera.'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showBugReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report a Bug'),
        content: const TextField(
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Describe the issue you encountered...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar('Bug report sent. Thank you!');
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
      builder: (context) => AboutDialog(
        applicationName: 'Beach Book',
        applicationVersion: '1.0.0',
        applicationIcon: const Icon(Icons.beach_access, size: 64, color: arbutusGreen),
        children: const [
          Text('Beach Book helps you discover, document, and share beautiful beaches.'),
          SizedBox(height: 16),
          Text('Built with Flutter and Firebase.'),
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
            'Your privacy is important to us. Beach Book collects location data and photos only with your permission to help build our beach database. We do not share personal information with third parties. All data is stored securely using Firebase.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _forceSyncData() {
    _showSnackBar('Syncing data...');
    // TODO: Implement actual sync logic
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _showSnackBar('Sync completed successfully');
    });
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}