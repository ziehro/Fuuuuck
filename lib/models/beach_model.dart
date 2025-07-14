// lib/models/beach_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
// Make sure this is imported correctly

class Beach {
  final String id; // Firestore Document ID
  final String name;
  final double latitude;
  final double longitude;
  final String geohash;
  final String country;
  final String province;
  final String municipality;
  final String description;
  final List<String> imageUrls; // Main images for the beach
  final Timestamp timestamp; // Creation timestamp
  final Timestamp lastAggregated; // When aggregation was last run
  final int totalContributions;
  final Map<String, double> aggregatedMetrics;
  final Map<String, String> aggregatedSingleChoices;
  final Map<String, List<String>> aggregatedMultiChoices;
  final Map<String, List<String>> aggregatedTextItems;
  final Map<String, int> identifiedFloraFaunaCounts;
  final Map<String, double> identifiedRockTypesComposition;
  final Map<String, double> identifiedBeachComposition;
  final String? aiGeneratedImageUrl;
  final List<String> discoveryQuestions;
  final String educationalInfo;
  final List<String> contributedDescriptions; // Add this line

  Beach({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.geohash,
    required this.country,
    required this.province,
    required this.municipality,
    required this.description,
    this.imageUrls = const [],
    required this.timestamp,
    required this.lastAggregated,
    required this.totalContributions,
    this.aggregatedMetrics = const {},
    this.aggregatedSingleChoices = const {},
    this.aggregatedMultiChoices = const {},
    this.aggregatedTextItems = const {},
    this.identifiedFloraFaunaCounts = const {},
    this.identifiedRockTypesComposition = const {},
    this.identifiedBeachComposition = const {},
    this.aiGeneratedImageUrl,
    this.discoveryQuestions = const [],
    this.educationalInfo = '',
    required this.contributedDescriptions,
  });

  // Create from Firestore DocumentSnapshot (Revised to be robust against nulls)
  factory Beach.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
    data ??= {}; // If data is null, initialize as an empty map

    // Use defensive programming with null-aware operators (??)
    return Beach(
      id: doc.id,
      name: data['name'] as String? ?? 'Unnamed Beach',
      // Get latitude and longitude from the old database structure
      latitude: (data['latitude'] as num? ?? 0.0).toDouble(),
      longitude: (data['longitude'] as num? ?? 0.0).toDouble(),
      geohash: data['geohash'] as String? ?? 'unknown',
      country: data['country'] as String? ?? '',
      province: data['province'] as String? ?? '',
      municipality: data['municipality'] as String? ?? '',
      description: data['description'] as String? ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      lastAggregated: data['lastAggregated'] as Timestamp? ?? Timestamp.now(),
      totalContributions: data['totalContributions'] as int? ?? 0,

      // Handle nested maps and lists defensively
      aggregatedMetrics: (data['aggregatedMetrics'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {},
      aggregatedSingleChoices: Map<String, String>.from(data['aggregatedSingleChoices'] ?? {}),
      aggregatedMultiChoices: (data['aggregatedMultiChoices'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, List<String>.from(v ?? []))) ?? {},
      aggregatedTextItems: (data['aggregatedTextItems'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, List<String>.from(v ?? []))) ?? {},
      identifiedFloraFaunaCounts: (data['identifiedFloraFaunaCounts'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as int)) ?? {},
      identifiedRockTypesComposition: (data['identifiedRockTypesComposition'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {},
      identifiedBeachComposition: (data['identifiedBeachComposition'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {},

      aiGeneratedImageUrl: data['aiGeneratedImageUrl'] as String?,
      discoveryQuestions: List<String>.from(data['discoveryQuestions'] ?? []),
      educationalInfo: data['educationalInfo'] as String? ?? '',
      contributedDescriptions: List<String>.from(data['contributedDescriptions'] ?? []), // Add this line
    );
  }

  // Convert to Map for Firestore (primarily for initial creation or admin updates)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'geohash': geohash,
      'country': country,
      'province': province,
      'municipality': municipality,
      'description': description,
      'imageUrls': imageUrls,
      'timestamp': timestamp,
      'lastAggregated': lastAggregated,
      'totalContributions': totalContributions,
      'aggregatedMetrics': aggregatedMetrics,
      'aggregatedSingleChoices': aggregatedSingleChoices,
      'aggregatedMultiChoices': aggregatedMultiChoices,
      'aggregatedTextItems': aggregatedTextItems,
      'identifiedFloraFaunaCounts': identifiedFloraFaunaCounts,
      'identifiedRockTypesComposition': identifiedRockTypesComposition,
      'identifiedBeachComposition': identifiedBeachComposition,
      'aiGeneratedImageUrl': aiGeneratedImageUrl,
      'discoveryQuestions': discoveryQuestions,
      'educationalInfo': educationalInfo,
      'contributedDescriptions': contributedDescriptions, // Add this line
    };
  }
}