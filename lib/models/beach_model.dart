// lib/models/beach_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Beach {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String geohash;
  final String country;
  final String province;
  final String municipality;
  final String description;
  final String aiDescription;
  final List<String> imageUrls;
  final List<String> contributedDescriptions;
  final Timestamp timestamp;
  final Timestamp lastAggregated;
  final int totalContributions;
  final Map<String, double> aggregatedMetrics;
  final Map<String, dynamic> aggregatedSingleChoices;
  final Map<String, dynamic> aggregatedMultiChoices;
  final Map<String, List<dynamic>> aggregatedTextItems;
  final Map<String, dynamic> identifiedFloraFauna;
  final Map<String, dynamic> identifiedRockTypesComposition;
  final Map<String, dynamic> identifiedBeachComposition;
  final List<String> discoveryQuestions;
  final String educationalInfo;
  final double? waterIndex;
  final double? shorelineRiskProxy;

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
    required this.aiDescription,
    required this.imageUrls,
    required this.contributedDescriptions,
    required this.timestamp,
    required this.lastAggregated,
    required this.totalContributions,
    required this.aggregatedMetrics,
    required this.aggregatedSingleChoices,
    required this.aggregatedMultiChoices,
    required this.aggregatedTextItems,
    required this.identifiedFloraFauna,
    required this.identifiedRockTypesComposition,
    required this.identifiedBeachComposition,
    required this.discoveryQuestions,
    required this.educationalInfo,
    this.waterIndex,
    this.shorelineRiskProxy,
  });

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
      'aiDescription': aiDescription,
      'imageUrls': imageUrls,
      'contributedDescriptions': contributedDescriptions,
      'timestamp': timestamp,
      'lastAggregated': lastAggregated,
      'totalContributions': totalContributions,
      'aggregatedMetrics': aggregatedMetrics,
      'aggregatedSingleChoices': aggregatedSingleChoices,
      'aggregatedMultiChoices': aggregatedMultiChoices,
      'aggregatedTextItems': aggregatedTextItems,
      'identifiedFloraFauna': identifiedFloraFauna,
      'identifiedRockTypesComposition': identifiedRockTypesComposition,
      'identifiedBeachComposition': identifiedBeachComposition,
      'discoveryQuestions': discoveryQuestions,
      'educationalInfo': educationalInfo,
      if (waterIndex != null) 'waterIndex': waterIndex,
      if (shorelineRiskProxy != null) 'shorelineRiskProxy': shorelineRiskProxy,
    };
  }

  factory Beach.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Beach(
      id: doc.id,
      name: data['name'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      geohash: data['geohash'] ?? '',
      country: data['country'] ?? '',
      province: data['province'] ?? '',
      municipality: data['municipality'] ?? '',
      description: data['description'] ?? '',
      aiDescription: data['aiDescription'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      contributedDescriptions: List<String>.from(data['contributedDescriptions'] ?? []),
      timestamp: data['timestamp'] ?? Timestamp.now(),
      lastAggregated: data['lastAggregated'] ?? Timestamp.now(),
      totalContributions: data['totalContributions'] ?? 0,
      aggregatedMetrics: Map<String, num>.from(data['aggregatedMetrics'] ?? {}).map((key, value) => MapEntry(key, value.toDouble())),
      aggregatedSingleChoices: Map<String, dynamic>.from(data['aggregatedSingleChoices'] ?? {}),
      aggregatedMultiChoices: Map<String, dynamic>.from(data['aggregatedMultiChoices'] ?? {}),
      aggregatedTextItems: Map<String, List<dynamic>>.from(data['aggregatedTextItems'] ?? {}),
      identifiedFloraFauna: Map<String, dynamic>.from(data['identifiedFloraFauna'] ?? {}),
      identifiedRockTypesComposition: Map<String, dynamic>.from(data['identifiedRockTypesComposition'] ?? {}),
      identifiedBeachComposition: Map<String, dynamic>.from(data['identifiedBeachComposition'] ?? {}),
      discoveryQuestions: List<String>.from(data['discoveryQuestions'] ?? []),
      educationalInfo: data['educationalInfo'] ?? '',
      waterIndex: data['waterIndex']?.toDouble(),
      shorelineRiskProxy: data['shorelineRiskProxy']?.toDouble(),
    );
  }
}