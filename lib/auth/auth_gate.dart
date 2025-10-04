// lib/auth/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:mybeachbook/services/auth_service.dart';
import 'package:mybeachbook/auth/login_page.dart';
import 'package:mybeachbook/auth/register_page.dart';

// Placeholder imports for your screens (ensure these paths are correct)
import 'package:mybeachbook/screens/scanner_screen.dart';
import 'package:mybeachbook/screens/map_screen.dart';
import 'package:mybeachbook/screens/add_beach_screen.dart';
import 'package:mybeachbook/screens/settings_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Local state to manage showing login or register page
  bool showLoginPage = true;

  void togglePages() {
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

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
          return const MyAppContent(); // Your main app content (the Scaffold with tabs)
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
  const MyAppContent({super.key});

  @override
  State<MyAppContent> createState() => _MyAppContentState();
}

class _MyAppContentState extends State<MyAppContent> {
  int _selectedIndex = 0; // Index for the currently selected tab

  // Global key to access MapScreen state
  final GlobalKey<MapScreenState> _mapScreenKey = GlobalKey<MapScreenState>();

  // List of widgets for each tab
  // Make sure the order here matches the BottomNavigationBarItem order
  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    _widgetOptions = <Widget>[
      MapScreen(key: _mapScreenKey),     // MAP is now the first tab
      const ScannerScreen(), // Scanner is the second tab
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
      await authService.signOut();
      // No need to navigate manually, AuthGate will automatically redirect
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

      // Layers menu (pick a metric from the bar)
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

    // Menu button with Settings and Sign Out (always visible on all tabs)
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
            icon: Icon(Icons.map), // Map icon for MapScreen
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt), // Camera icon for ScannerScreen
            label: 'Scan',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      // Show FAB only on Map tab
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddBeachScreen())
          );
        },
        tooltip: 'Add New Beach',
        child: const Icon(Icons.add_location_alt),
      )
          : null,
    );
  }
}