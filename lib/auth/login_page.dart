// lib/auth/login_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fuuuuck/services/auth_service.dart'; // Make sure this import is correct
import 'package:fuuuuck/main.dart'; // For accessing theme colors

class LoginPage extends StatefulWidget {
  final VoidCallback? onRegisterTap; // Callback to switch to register page

  const LoginPage({super.key, this.onRegisterTap});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;

  Future<void> _signIn() async {
    setState(() {
      _errorMessage = null; // Clear previous errors
    });
    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      await authService.signInWithEmailPassword(
        _emailController.text,
        _passwordController.text,
      );
      // Success, app will automatically navigate to authenticated state
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', ''); // Clean up error message
      });
      debugPrint('Login Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: arbutusCream, // Use your defined theme color
      appBar: AppBar(
        title: const Text('Login', style: TextStyle(color: arbutusCream)),
        backgroundColor: arbutusBrown,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Icons.beach_access, size: 80, color: arbutusGreen), // App icon
              const SizedBox(height: 20),
              Text('Welcome to Beach Book!', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email, color: arbutusBrown),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: arbutusGreen, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock, color: arbutusBrown),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: arbutusGreen, width: 2),
                  ),
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _signIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: arbutusGreen, // Button background
                  foregroundColor: arbutusCream, // Button text color
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Sign In', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: widget.onRegisterTap,
                style: TextButton.styleFrom(
                  foregroundColor: arbutusBrown,
                ),
                child: const Text("Don't have an account? Register here"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}