// lib/models/beach_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fuuuuck/models/confirmed_identification.dart'; // To use ConfirmedIdentification for aggregated AI

class Beach {
  final String id; // Firestore Document ID
  final String name;
  final GeoPoint location; // Firestore GeoPoint type for efficient queries
  final String geohash;
  final String country;
  final String province;
  final String municipality;
  final String description;
  final List<String> imageUrls; // Main images for the beach
  final Timestamp timestamp; // Creation timestamp
  final Timestamp lastAggregated; // When aggregation was last run
  final int totalContributions;

  // Aggregated Data - Averages, Most Common, or Consolidated Lists
  final Map<String, double> aggregatedMetrics; // For numerical/rating data (average)
  final Map<String, String> aggregatedSingleChoices; // For single choice data (most common string)
  final Map<String, List<String>> aggregatedMultiChoices; // For multi-choice data (consolidated list of common options)
  final Map<String, List<String>> aggregatedTextItems; // For free text lists (consolidated unique items)

  // Aggregated AI Data
  final Map<String, int> identifiedFloraFaunaCounts; // Map of taxon name to count
  final Map<String, double> identifiedRockTypesComposition; // Map of rock type to percentage
  final Map<String, double> identifiedBeachComposition; // Map of composition type to percentage

  // Educational/AI Generated Content
  final String? aiGeneratedImageUrl; // URL to the AI-generated image of the beach
  final List<String> discoveryQuestions; // Fixed questions for kids
  final String educationalInfo;

  Beach({
    required this.id,
    required this.name,
    required this.location,
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
  });

  // Create from Firestore DocumentSnapshot
  factory Beach.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Beach(
      id: doc.id,
      name: data['name'] as String,
      location: data['location'] as GeoPoint,
      geohash: data['geohash'] as String,
      country: data['country'] as String,
      province: data['province'] as String,
      municipality: data['municipality'] as String,
      description: data['description'] as String,
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      timestamp: data['timestamp'] as Timestamp,
      lastAggregated: data['lastAggregated'] as Timestamp,
      totalContributions: data['totalContributions'] as int,
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
    );
  }

  // Convert to Map for Firestore (primarily for initial creation or admin updates)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'location': location,
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
    };
  }
}