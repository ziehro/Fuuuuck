// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fuuuuck/services/sync_service.dart';

import 'package:fuuuuck/firebase_options.dart';
import 'package:fuuuuck/services/auth_service.dart'; // Import AuthService
import 'package:fuuuuck/auth/auth_gate.dart';       // Import AuthGate
import 'package:fuuuuck/services/beach_data_service.dart';

// Theme colors based on Arbutus tree (example values)
const Color arbutusBrown = Color(0xFF8B4513); // Saddle Brown
const Color arbutusRed = Color(0xFFA52A2A);  // Brownish Red
const Color arbutusGreen = Color(0xFF228B22); // Forest Green
const Color arbutusCream = Color(0xFFF5F5DC); // Beige

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  SyncService();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthService()),
        // Add BeachDataService as a regular Provider (not ChangeNotifier as it doesn't change state it provides)
        Provider<BeachDataService>(create: (context) => BeachDataService()),
      ],
      child: const RootApp(),
    ),
  );
}
// Renamed MyApp to RootApp to clearly separate it from MyAppContent
class RootApp extends StatelessWidget {
  const RootApp({super.key});

  // Define the MaterialColor swatch as a static final here
  static final MaterialColor _arbutusBrownSwatch = _createMaterialColor(arbutusBrown);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beach Book',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: arbutusBrown,
        primarySwatch: _arbutusBrownSwatch,
        appBarTheme: const AppBarTheme(
          backgroundColor: arbutusBrown,
          foregroundColor: arbutusCream,
        ),
        scaffoldBackgroundColor: arbutusCream,
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: arbutusBrown,
          selectedItemColor: arbutusGreen,
          unselectedItemColor: arbutusCream,
          type: BottomNavigationBarType.fixed,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: arbutusGreen,
          foregroundColor: Colors.white,
        ),
        cardTheme: const CardThemeData(
          color: arbutusRed,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.grey),
          bodyMedium: TextStyle(color: Colors.grey),
          titleLarge: TextStyle(color: arbutusBrown, fontWeight: FontWeight.bold),
        ),
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: _arbutusBrownSwatch,
        ).copyWith(
          secondary: arbutusGreen,
        ),
      ),
      home: const AuthGate(), // Your app's entry point for auth flow
    );
  }

  // Helper function to create a MaterialColor from a single Color
  // Keep this as a top-level function or static method if used outside the class
  static MaterialColor _createMaterialColor(Color color) {
    List<double> strengths = <double>[.05];
    Map<int, Color> swatch = {};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }
}