// lib/auth/auth_gate.dart
// FIXED VERSION - Prevents permission errors for non-admin users

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:mybeachbook/services/auth_service.dart';
import 'package:mybeachbook/services/notification_service.dart';
import 'package:mybeachbook/auth/login_page.dart';
import 'package:mybeachbook/auth/register_page.dart';
import 'package:mybeachbook/screens/map_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool showLoginPage = true;

  // Admin user IDs - REPLACE WITH YOUR ACTUAL UID
  static const List<String> _adminUserIds = [
    't8xTPHecHIRY8nWcvmQBzWouBIh1', // REPLACE THIS
  ];

  void togglePages() {
    setState(() {
      showLoginPage = !showLoginPage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // User is logged in - show MapScreen directly (full screen)
        if (snapshot.hasData) {
          final user = snapshot.data!;
          final isAdmin = _adminUserIds.contains(user.uid);

          // Initialize notification service for admin users
          if (isAdmin) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final notificationService = Provider.of<NotificationService>(context, listen: false);
              notificationService.startListening();
            });
          }

          return MapScreen(isAdmin: isAdmin);
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