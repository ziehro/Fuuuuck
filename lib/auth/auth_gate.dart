// lib/auth/auth_gate.dart
// UPDATED VERSION - Add notification badge for admin

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:mybeachbook/services/auth_service.dart';
import 'package:mybeachbook/services/notification_service.dart'; // ADD THIS
import 'package:mybeachbook/auth/login_page.dart';
import 'package:mybeachbook/auth/register_page.dart';

// Placeholder imports for your screens (ensure these paths are correct)
import 'package:mybeachbook/screens/scanner_screen.dart';
import 'package:mybeachbook/screens/map_screen.dart';
import 'package:mybeachbook/screens/add_beach_screen.dart';
import 'package:mybeachbook/screens/settings_screen.dart';
import 'package:mybeachbook/screens/moderation_screen.dart'; // ADD THIS

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Local state to manage showing login or register page
  bool showLoginPage = true;

  // Admin user IDs - REPLACE WITH YOUR ACTUAL UID
  static const List<String> _adminUserIds = [
    'c4So8SbUIpYPsV0bF0aaAtyWj9q1', // REPLACE THIS
  ];

  void togglePages() {
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final notificationService = Provider.of<NotificationService>(context); // ADD THIS

    // Listen to authentication state changes
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading spinner while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User is logged in
        if (snapshot.hasData) {
          final user = snapshot.data!;
          final isAdmin = _adminUserIds.contains(user.uid);

          // Start notification service for admin users
          if (isAdmin) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              notificationService.startListening();
            });
          } else {
            // Stop listening if not admin
            WidgetsBinding.instance.addPostFrameCallback((_) {
              notificationService.stopListening();
            });
          }

          return MyAppContent(isAdmin: isAdmin);
        }

        // User is NOT logged in, show auth pages
        if (showLoginPage) {
          return LoginPage(onRegisterTap: togglePages);
        } else {
          return RegisterPage(onLoginTap: togglePages);
        }
      },
    );
  }
}

// Extracted MyApp's Scaffold content into a separate widget
class MyAppContent extends StatefulWidget {
  final bool isAdmin;

  const MyAppContent({super.key, required this.isAdmin});

  @override
  State<MyAppContent> createState() => _MyAppContentState();
}

class _MyAppContentState extends State<MyAppContent> {
  int _selectedIndex = 0; // Index for the currently selected tab

  // Global key to access MapScreen state
  final GlobalKey<MapScreenState> _mapScreenKey = GlobalKey<MapScreenState>();

  // List of widgets for each tab
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      MapScreen(key: _mapScreenKey),
      const ScannerScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Get the app bar title based on selected tab
  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Beaches';
      case 1:
        return 'Scanner';
      default:
        return 'Beach Book';
    }
  }

  // Show confirmation dialog before signing out
  Future<void> _showSignOutConfirmation() async {
    final bool? shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut == true) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final notificationService = Provider.of<NotificationService>(context, listen: false);

      // Stop notification service when signing out
      notificationService.stopListening();

      await authService.signOut();
    }
  }

  // Get the app bar actions based on selected tab
  List<Widget> _getAppBarActions() {
    List<Widget> actions = [];

    // Map-specific actions
    if (_selectedIndex == 0) {
      // Toggle markers on/off
      actions.add(
        IconButton(
          tooltip: 'Toggle markers',
          icon: const Icon(Icons.location_pin),
          onPressed: () {
            _mapScreenKey.currentState?.toggleMarkers();
          },
        ),
      );

      // Layers menu
      actions.add(
        PopupMenuButton<String?>(
          tooltip: 'Heatmap layer',
          icon: const Icon(Icons.layers),
          onSelected: (val) {
            _mapScreenKey.currentState?.setActiveMetric(val);
          },
          itemBuilder: (context) {
            final keys = MapScreen.getMetricKeys().toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
            return <PopupMenuEntry<String?>>[
              const PopupMenuItem<String?>(
                value: null,
                child: Text('None'),
              ),
              const PopupMenuDivider(),
              ...keys.map((k) => PopupMenuItem<String?>(
                value: k,
                child: Text(k),
              )),
            ];
          },
        ),
      );

      // Clear heatmap
      actions.add(
        IconButton(
          tooltip: 'Clear heatmap',
          icon: const Icon(Icons.layers_clear),
          onPressed: () {
            _mapScreenKey.currentState?.clearHeatmap();
          },
        ),
      );
    }

    // NOTIFICATION BADGE FOR ADMIN (show on all screens)
    if (widget.isAdmin) {
      actions.add(_buildNotificationBadge());
    }

    // Menu button with Settings and Sign Out (always visible)
    actions.add(
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        tooltip: 'Menu',
        onSelected: (value) {
          if (value == 'settings') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          } else if (value == 'sign_out') {
            _showSignOutConfirmation();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem<String>(
            value: 'settings',
            child: Row(
              children: [
                Icon(Icons.settings),
                SizedBox(width: 12),
                Text('Settings'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'sign_out',
            child: Row(
              children: [
                Icon(Icons.logout, color: Colors.red),
                SizedBox(width: 12),
                Text('Sign Out', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );

    return actions;
  }

  // NEW: Build notification badge for admin
  Widget _buildNotificationBadge() {
    return Consumer<NotificationService>(
      builder: (context, notificationService, child) {
        final count = notificationService.totalPendingCount;

        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications),
              tooltip: 'Moderation Queue',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ModerationScreen(),
                  ),
                );
              },
            ),
            if (count > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    count > 99 ? '99+' : count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        actions: _getAppBarActions(),
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Scan',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddBeachScreen()),
          );
        },
        tooltip: 'Add New Beach',
        child: const Icon(Icons.add_location_alt),
      )
          : null,
      floatingActionButtonLocation: _selectedIndex == 0
          ? CustomFabLocation(FloatingActionButtonLocation.startFloat, 15.0)
          : FloatingActionButtonLocation.endFloat,
    );
  }
}

class CustomFabLocation extends FloatingActionButtonLocation {
  final FloatingActionButtonLocation location;
  final double offsetY;

  const CustomFabLocation(this.location, this.offsetY);

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final Offset offset = location.getOffset(scaffoldGeometry);
    return Offset(offset.dx, offset.dy - offsetY);
  }
}