// lib/auth/register_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mybeachbook/services/auth_service.dart';
import 'package:mybeachbook/main.dart';

// Import the beachy theme colors
// These are already defined in main.dart, so we just reference them

class RegisterPage extends StatefulWidget {
  final VoidCallback? onLoginTap;

  const RegisterPage({super.key, this.onLoginTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  String? _errorMessage;

  Future<void> _signUp() async {
    setState(() {
      _errorMessage = null;
    });

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
      });
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      await authService.signUpWithEmailPassword(
        _emailController.text,
        _passwordController.text,
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
      debugPrint('Register Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: sandBeige,
      appBar: AppBar(
        title: const Text('Register'),
        backgroundColor: oceanBlue,
        foregroundColor: waveWhite,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Beach/nature icon with gradient
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [sunsetOrange, coralPink],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wb_sunny,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Join Beach Book!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: oceanBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start your beach exploration journey',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: driftwood,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email, color: seafoamGreen),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock, color: seafoamGreen),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: Icon(Icons.lock_outline, color: seafoamGreen),
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: coralPink, fontSize: 14),
                  ),
                ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _signUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: seafoamGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Register', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: widget.onLoginTap,
                style: TextButton.styleFrom(
                  foregroundColor: oceanBlue,
                ),
                child: const Text(
                  'Already have an account? Sign In',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}