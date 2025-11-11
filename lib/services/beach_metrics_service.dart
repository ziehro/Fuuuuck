// lib/services/beach_metrics_service.dart

import '../models/beach_model.dart';

class BeachMetricsService {
  // Calculate biodiversity score from identified flora/fauna
  static double calculateBiodiversityScore(Beach beach) {
    final floraFaunaCount = beach.identifiedFloraFauna.length;

    // Normalize to 0-10 scale (assuming max ~50 species is exceptional)
    return (floraFaunaCount / 5.0).clamp(0.0, 10.0);
  }

  // Calculate beach composition diversity
  static double calculateBeachDiversity(Beach beach) {
    int diversityScore = 0;

    // Count different composition types present
    final compositions = beach.identifiedBeachComposition;
    if (compositions.isNotEmpty) {
      diversityScore += compositions.length;
    }

    // Add rock type diversity
    final rockTypes = beach.identifiedRockTypesComposition;
    if (rockTypes.isNotEmpty) {
      diversityScore += rockTypes.length;
    }

    // Normalize to 0-10 scale
    return (diversityScore / 2.0).clamp(0.0, 10.0);
  }

  // Location confidence (0-10, where 10 is refined)
  static double getLocationConfidence(Beach beach) {
    return (beach.locationRefined ?? false) ? 10.0 : 3.0;
  }
}