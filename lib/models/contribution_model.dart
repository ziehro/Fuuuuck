// lib/models/contribution_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fuuuuck/models/confirmed_identification.dart'; // Import the new model

class Contribution {
  final String? id; // Document ID, nullable when creating a new one
  final String userId;
  final String userEmail; // <-- ADD THIS LINE
  final Timestamp timestamp;
  final double latitude;
  final double longitude;
  final List<String> contributedImageUrls;

  // Manual Answers - these directly mirror your old app's 'data' map
  final Map<String, dynamic> userAnswers; // This map will hold all the dynamic questions

  // AI Confirmed Identifications
  final List<ConfirmedIdentification> aiConfirmedFloraFauna;
  final List<ConfirmedIdentification> aiConfirmedRockTypes; // Placeholder for future rock AI

  Contribution({
    this.id,
    required this.userId,
    required this.userEmail, // <-- ADD THIS LINE
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.contributedImageUrls = const [],
    required this.userAnswers,
    this.aiConfirmedFloraFauna = const [],
    this.aiConfirmedRockTypes = const [],
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userEmail': userEmail, // <-- ADD THIS LINE
      'timestamp': timestamp,
      'latitude': latitude,
      'longitude': longitude,
      'contributedImageUrls': contributedImageUrls,
      'userAnswers': userAnswers,
      'aiConfirmedFloraFauna': aiConfirmedFloraFauna.map((e) => e.toMap()).toList(),
      'aiConfirmedRockTypes': aiConfirmedRockTypes.map((e) => e.toMap()).toList(),
    };
  }

  // Create from Firestore DocumentSnapshot
  factory Contribution.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Contribution(
      id: doc.id,
      userId: data['userId'] as String,
      userEmail: data['userEmail'] as String? ?? '', // <-- ADD THIS LINE (handle missing emails gracefully)
      timestamp: data['timestamp'] as Timestamp,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      contributedImageUrls: List<String>.from(data['contributedImageUrls'] ?? []),
      userAnswers: Map<String, dynamic>.from(data['userAnswers'] ?? {}),
      aiConfirmedFloraFauna: (data['aiConfirmedFloraFauna'] as List<dynamic>?)
          ?.map((e) => ConfirmedIdentification.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      aiConfirmedRockTypes: (data['aiConfirmedRockTypes'] as List<dynamic>?)
          ?.map((e) => ConfirmedIdentification.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}