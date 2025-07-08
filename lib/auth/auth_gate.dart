// lib/auth/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:fuuuuck/services/auth_service.dart';
import 'package:fuuuuck/auth/login_page.dart';
import 'package:fuuuuck/auth/register_page.dart';

// Placeholder imports for your screens (ensure these paths are correct)
import 'package:fuuuuck/screens/scanner_screen.dart';
import 'package:fuuuuck/screens/map_screen.dart';

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

  // List of widgets for each tab
  // Make sure the order here matches the BottomNavigationBarItem order
  static final List<Widget> _widgetOptions = <Widget>[
    const MapScreen(),     // MAP is now the first tab
    const ScannerScreen(), // Scanner is the second tab
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Access AuthService to get current user info or sign out
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beach Book'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to settings screen
              print('Settings button pressed');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              // No need to navigate manually, AuthGate will automatically redirect
            },
            tooltip: 'Sign Out',
          ),
        ],
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
      // The FloatingActionButton for "Add New Beach" is now in MapScreen.dart,
      // so it's removed from here to avoid duplication.
    );
  }
}