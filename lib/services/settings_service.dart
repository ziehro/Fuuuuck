// lib/services/settings_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  String _mapStyle = 'normal';
  bool _showMarkerLabels = true;
  double _defaultZoomLevel = 10.0;
  bool _autoSyncEnabled = true;
  bool _offlineModeEnabled = false;
  bool _notificationsEnabled = false;
  bool _enableHapticFeedback = true;
  String _measurementUnit = 'Steps';
  String? _premiumAccessCode;
  DateTime? _premiumAccessExpiry;

  String get mapStyle => _mapStyle;
  bool get showMarkerLabels => _showMarkerLabels;
  double get defaultZoomLevel => _defaultZoomLevel;
  bool get autoSyncEnabled => _autoSyncEnabled;
  bool get offlineModeEnabled => _offlineModeEnabled;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get enableHapticFeedback => _enableHapticFeedback;
  String get measurementUnit => _measurementUnit;

  bool get hasPremiumAccess {
    if (_premiumAccessExpiry == null) return false;
    return DateTime.now().isBefore(_premiumAccessExpiry!);
  }

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
    _premiumAccessCode = prefs.getString('premiumAccessCode');
    final expiryString = prefs.getString('premiumAccessExpiry');
    if (expiryString != null) {
      _premiumAccessExpiry = DateTime.tryParse(expiryString);
    }

    notifyListeners();
  }

  Future<bool> validateAndSetPremiumAccess(String code) async {
    // Hardcoded codes with expiry dates - you can modify these as needed
    final Map<String, DateTime> validCodes = {
      'BEACH2025': DateTime(2025, 12, 31),
      'PREMIUM30': DateTime.now().add(const Duration(days: 30)),
      'TRIAL7': DateTime.now().add(const Duration(days: 7)),
    };

    if (validCodes.containsKey(code)) {
      _premiumAccessCode = code;
      _premiumAccessExpiry = validCodes[code]!;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('premiumAccessCode', code);
      await prefs.setString('premiumAccessExpiry', _premiumAccessExpiry!.toIso8601String());

      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> clearPremiumAccess() async {
    _premiumAccessCode = null;
    _premiumAccessExpiry = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('premiumAccessCode');
    await prefs.remove('premiumAccessExpiry');

    notifyListeners();
  }

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

  Future<void> setMeasurementUnit(String value) async {
    _measurementUnit = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('measurementUnit', value);
    notifyListeners();
  }

  Future<void> clearCache() async {
    // Placeholder for cache clearing logic
  }
}