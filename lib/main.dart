// lib/main.dart
// UPDATED VERSION - Add NotificationService provider

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mybeachbook/services/sync_service.dart';

import 'package:mybeachbook/firebase_options.dart';
import 'package:mybeachbook/services/auth_service.dart';
import 'package:mybeachbook/services/settings_service.dart';
import 'package:mybeachbook/services/notification_service.dart'; // ADD THIS
import 'package:mybeachbook/auth/auth_gate.dart';
import 'package:mybeachbook/services/beach_data_service.dart';

// 🏖️ BEACHY THEME COLORS
const Color oceanBlue = Color(0xFF0077BE);
const Color skyBlue = Color(0xFF87CEEB);
const Color sandBeige = Color(0xFFF4E4C1);
const Color seafoamGreen = Color(0xFF7FCDCD);
const Color sunsetOrange = Color(0xFFFF8C42);
const Color coralPink = Color(0xFFFF6B9D);
const Color driftwood = Color(0xFFB8956A);
const Color waveWhite = Color(0xFFFFFFF0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  /*await FirebaseAppCheck.instance.activate(
    androidProvider: Platform.isAndroid
        ? AndroidProvider.debug
        : AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );*/

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  SyncService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthService()),
        ChangeNotifierProvider(create: (context) => SettingsService()),
        ChangeNotifierProvider(create: (context) => NotificationService()), // ADD THIS
        Provider<BeachDataService>(create: (context) => BeachDataService()),
      ],
      child: const RootApp(),
    ),
  );
}

// Rest of the file stays the same...
class RootApp extends StatelessWidget {
  const RootApp({super.key});

  static final MaterialColor _oceanBlueSwatch = _createMaterialColor(oceanBlue);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beach Book',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,

        // Primary colors
        primaryColor: oceanBlue,
        primarySwatch: _oceanBlueSwatch,
        colorScheme: ColorScheme.fromSeed(
          seedColor: oceanBlue,
          primary: oceanBlue,
          secondary: seafoamGreen,
          tertiary: coralPink,
          surface: waveWhite,
          background: sandBeige,
        ),

        // Scaffold
        scaffoldBackgroundColor: sandBeige,

        // AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: oceanBlue,
          foregroundColor: waveWhite,
          elevation: 2,
          centerTitle: false,
        ),

        // Cards
        cardTheme: CardThemeData(
          color: waveWhite,
          elevation: 3,
          shadowColor: oceanBlue.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
        ),

        // Floating Action Button
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: seafoamGreen,
          foregroundColor: Colors.white,
          elevation: 4,
        ),

        // Bottom Navigation Bar
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: oceanBlue,
          selectedItemColor: seafoamGreen,
          unselectedItemColor: skyBlue,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),

        // Elevated Button
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: seafoamGreen,
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // Text Button
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: oceanBlue,
          ),
        ),

        // Input Decoration
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: waveWhite,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: skyBlue.withOpacity(0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: skyBlue.withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: seafoamGreen, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: coralPink, width: 1),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),

        // Chip
        chipTheme: ChipThemeData(
          backgroundColor: skyBlue.withOpacity(0.3),
          selectedColor: seafoamGreen,
          secondarySelectedColor: seafoamGreen,
          labelStyle: const TextStyle(color: oceanBlue),
          secondaryLabelStyle: const TextStyle(color: Colors.white),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),

        // Text Theme
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: oceanBlue, fontWeight: FontWeight.bold),
          displayMedium: TextStyle(color: oceanBlue, fontWeight: FontWeight.bold),
          displaySmall: TextStyle(color: oceanBlue, fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(color: oceanBlue, fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(color: oceanBlue, fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(color: oceanBlue, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: oceanBlue, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: oceanBlue, fontWeight: FontWeight.w600),
          titleSmall: TextStyle(color: oceanBlue, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: driftwood),
          bodyMedium: TextStyle(color: driftwood),
          bodySmall: TextStyle(color: driftwood),
          labelLarge: TextStyle(color: oceanBlue),
          labelMedium: TextStyle(color: oceanBlue),
          labelSmall: TextStyle(color: driftwood),
        ),

        // Icon Theme
        iconTheme: const IconThemeData(
          color: oceanBlue,
        ),

        // Divider
        dividerTheme: DividerThemeData(
          color: skyBlue.withOpacity(0.3),
          thickness: 1,
        ),

        // Slider
        sliderTheme: SliderThemeData(
          activeTrackColor: seafoamGreen,
          inactiveTrackColor: skyBlue.withOpacity(0.3),
          thumbColor: seafoamGreen,
          overlayColor: seafoamGreen.withOpacity(0.2),
        ),

        // Switch
        switchTheme: SwitchThemeData(
          thumbColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return seafoamGreen;
            }
            return Colors.grey;
          }),
          trackColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return seafoamGreen.withOpacity(0.5);
            }
            return Colors.grey.withOpacity(0.3);
          }),
        ),
      ),
      home: const AuthGate(),
    );
  }

  // Helper function to create a MaterialColor from a single Color
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