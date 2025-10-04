// lib/services/settings_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  // Map Settings
  String _mapStyle = 'normal';
  bool _showMarkerLabels = true;
  double _defaultZoomLevel = 10.0;

  // Data & Sync Settings
  bool _autoSyncEnabled = true;
  bool _offlineModeEnabled = false;

  // Notifications & Feedback
  bool _notificationsEnabled = false;
  bool _enableHapticFeedback = true;

  // Measurements
  String _measurementUnit = 'Steps';

  // Getters
  String get mapStyle => _mapStyle;
  bool get showMarkerLabels => _showMarkerLabels;
  double get defaultZoomLevel => _defaultZoomLevel;
  bool get autoSyncEnabled => _autoSyncEnabled;
  bool get offlineModeEnabled => _offlineModeEnabled;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get enableHapticFeedback => _enableHapticFeedback;
  String get measurementUnit => _measurementUnit;

  // Initialize settings from storage
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _mapStyle = prefs.getString('mapStyle') ?? 'normal';
    _showMarkerLabels = prefs.getBool('showMarkerLabels') ?? true;
    _defaultZoomLevel = prefs.getDouble('defaultZoomLevel') ?? 10.0;
    _autoSyncEnabled = prefs.getBool('autoSyncEnabled') ?? true;
    _offlineModeEnabled = prefs.getBool('offlineModeEnabled') ?? false;
    _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
    _enableHapticFeedback = prefs.getBool('enableHapticFeedback') ?? true;
    _measurementUnit = prefs.getString('measurementUnit') ?? 'Steps';

    notifyListeners();
  }

  // Map Settings Setters
  Future<void> setMapStyle(String style) async {
    _mapStyle = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mapStyle', style);
    notifyListeners();
  }

  Future<void> setShowMarkerLabels(bool value) async {
    _showMarkerLabels = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showMarkerLabels', value);
    notifyListeners();
  }

  Future<void> setDefaultZoomLevel(double value) async {
    _defaultZoomLevel = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('defaultZoomLevel', value);
    notifyListeners();
  }

  // Data & Sync Setters
  Future<void> setAutoSyncEnabled(bool value) async {
    _autoSyncEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoSyncEnabled', value);
    notifyListeners();
  }

  Future<void> setOfflineModeEnabled(bool value) async {
    _offlineModeEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('offlineModeEnabled', value);
    notifyListeners();
  }

  // Notifications & Feedback Setters
  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', value);
    notifyListeners();
  }

  Future<void> setEnableHapticFeedback(bool value) async {
    _enableHapticFeedback = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableHapticFeedback', value);
    notifyListeners();
  }

  // Measurements Setter
  Future<void> setMeasurementUnit(String value) async {
    _measurementUnit = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('measurementUnit', value);
    notifyListeners();
  }

  // Clear all cached data
  Future<void> clearCache() async {
    // This will be implemented with actual cache clearing logic
    // For now, just a placeholder
  }
}