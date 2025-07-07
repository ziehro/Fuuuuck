// lib/models/confirmed_identification.dart

class ConfirmedIdentification {
  final String commonName;
  final String scientificName;
  final int taxonId;
  final String imageUrl;

  ConfirmedIdentification({
    required this.commonName,
    required this.scientificName,
    required this.taxonId,
    required this.imageUrl,
  });

  // Convert to a Map for storage in Firestore
  Map<String, dynamic> toMap() {
    return {
      'commonName': commonName,
      'scientificName': scientificName,
      'taxonId': taxonId,
      'imageUrl': imageUrl,
    };
  }

  // Create from a Map retrieved from Firestore
  factory ConfirmedIdentification.fromMap(Map<String, dynamic> map) {
    return ConfirmedIdentification(
      commonName: map['commonName'] as String,
      scientificName: map['scientificName'] as String,
      taxonId: map['taxonId'] as int,
      imageUrl: map['imageUrl'] as String,
    );
  }
}