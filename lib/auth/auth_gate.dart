// lib/auth/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:fuuuuck/services/auth_service.dart';
import 'package:fuuuuck/auth/login_page.dart';
import 'package:fuuuuck/auth/register_page.dart';
import 'package:fuuuuck/main.dart'; // For MyApp content or directly show Scaffold
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
        // Show loading spinner
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User is logged in
        if (snapshot.hasData) {
          return const MyAppContent(); // Your main app content (e.g., the Scaffold with tabs)
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

// Extract MyApp's Scaffold content into a separate widget
class MyAppContent extends StatefulWidget {
  const MyAppContent({super.key});

  @override
  State<MyAppContent> createState() => _MyAppContentState();
}

class _MyAppContentState extends State<MyAppContent> {
  int _selectedIndex = 0; // Index for the currently selected tab

  // List of widgets for each tab
  static final List<Widget> _widgetOptions = <Widget>[
    const ScannerScreen(), // Placeholder for Scanner
    const MapScreen(), // Placeholder for Map
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
              // No need to navigate, AuthGate will automatically redirect
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
            icon: Icon(Icons.camera_alt),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}