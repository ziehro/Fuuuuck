// lib/services/migration_service.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fuuuuck/models/beach_model.dart';
import 'package:fuuuuck/models/contribution_model.dart';
import 'package:fuuuuck/models/confirmed_identification.dart';
import 'package:fuuuuck/services/gemini_service.dart';
import 'package:dart_geohash/dart_geohash.dart';

class MigrationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GeoHasher _geoHasher = GeoHasher();
  final GeminiService _geminiService = GeminiService();

  // Collection names
  static const String oldCollectionName = 'locations';
  static const String newCollectionName = 'beaches';
  static const String migrationTrackingCollection = 'migration_tracking';

  // Migration control
  bool _isPaused = false;
  bool _shouldStop = false;

  // In-memory cache of processed UUIDs for current session
  final Set<String> _processedUuids = <String>{};
  bool _trackingCacheLoaded = false;

  // Choice mappings for multi-choice fields based on your old app
  static const Map<String, List<String>> multiChoiceOptions = {
    'Bluff Comp': ['Sand', 'Rock', 'Thick Brush', 'Grass'],
    'Man Made': ['Seawall', 'Sewar Line', 'Walkway', 'Garbage Cans', 'Tents', 'Picnic Tables', 'Benches', 'Houses', 'Playground', 'Bathrooms', 'Campground', 'Protective Structure To Escape the Weather', 'Boat Dock', 'Boat Launch'],
    'Shade': ['in the morning', 'in the evening', 'in the afternoon', 'none'],
    'Which Shells': ['Butter Clam', 'Mussel', 'Crab', 'Oyster', 'Whelks', 'Turban', 'Sand dollars', 'Cockles', 'Starfish', 'Limpets'],
  };

  static const Map<String, List<String>> singleChoiceOptions = {
    'Best Tide': ['Low', 'Mid', 'High', "Don't Matter"],
    'Parking': ['Parked on the beach', '1 minute', '5 minutes', '10 minutes', '30 minutes', '1 hour plus', 'Boat access only'],
    'Rock Type': ['Igneous', 'Sedimentary', 'Metamorphic'],
    'Shape': ['Concave', 'Convex', 'Isthmus', 'Horseshoe', 'Straight'],
  };

  // Control methods
  void pauseMigration() => _isPaused = true;
  void resumeMigration() => _isPaused = false;
  void stopMigration() => _shouldStop = true;
  void resetMigrationState() {
    _isPaused = false;
    _shouldStop = false;
    _processedUuids.clear();
    _trackingCacheLoaded = false;
  }

  /// Load the tracking cache once per migration session
  Future<void> _loadTrackingCache() async {
    if (_trackingCacheLoaded) return;

    try {
      final QuerySnapshot trackingDocs = await _firestore
          .collection(migrationTrackingCollection)
          .get();

      for (final doc in trackingDocs.docs) {
        _processedUuids.add(doc.id);
      }

      _trackingCacheLoaded = true;
      print('📋 Loaded ${_processedUuids.length} processed UUIDs from tracking cache');
    } catch (e) {
      print('⚠️ Error loading tracking cache: $e');
      _trackingCacheLoaded = true; // Continue anyway
    }
  }

  /// Check if a UUID has already been processed
  Future<bool> _isAlreadyProcessed(String uuid) async {
    await _loadTrackingCache();
    return _processedUuids.contains(uuid);
  }

  /// Mark a UUID as processed
  Future<void> _markAsProcessed(String uuid, String beachName, String newBeachId) async {
    try {
      await _firestore.collection(migrationTrackingCollection).doc(uuid).set({
        'originalId': uuid,
        'newBeachId': newBeachId,
        'beachName': beachName,
        'processedAt': Timestamp.now(),
        'migrationVersion': '1.0',
      });

      _processedUuids.add(uuid);
    } catch (e) {
      print('⚠️ Error marking UUID as processed: $e');
    }
  }

  /// Enhanced duplicate detection with multiple strategies
  Future<bool> _isDuplicate(String uuid, Map<String, dynamic> oldData, Function(String)? onProgress) async {
    // Strategy 1: UUID tracking (fastest)
    if (await _isAlreadyProcessed(uuid)) {
      _log('🔄 UUID already processed: $uuid', onProgress);
      return true;
    }

    // Strategy 2: Name + location proximity (for safety)
    final existingBeach = await _findExistingBeach(oldData);
    if (existingBeach != null) {
      _log('📍 Found existing beach by location: ${existingBeach.name}', onProgress);
      // Mark this UUID as processed even though we found it by location
      await _markAsProcessed(uuid, existingBeach.name, existingBeach.id);
      return true;
    }

    return false;
  }

  /// Clear all migration tracking (use with caution!)
  Future<void> clearMigrationTracking({Function(String)? onProgress}) async {
    _log('🗑️ Clearing migration tracking data...', onProgress);

    try {
      final QuerySnapshot trackingDocs = await _firestore
          .collection(migrationTrackingCollection)
          .get();

      final batch = _firestore.batch();
      for (final doc in trackingDocs.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      _processedUuids.clear();
      _trackingCacheLoaded = false;

      _log('✅ Cleared ${trackingDocs.docs.length} tracking records', onProgress);
    } catch (e) {
      _log('❌ Error clearing tracking: $e', onProgress);
    }
  }

  /// Get migration statistics
  Future<Map<String, int>> getMigrationStats() async {
    try {
      final oldCount = (await _firestore.collection(oldCollectionName).get()).docs.length;
      final newCount = (await _firestore.collection(newCollectionName).get()).docs.length;
      final processedCount = (await _firestore.collection(migrationTrackingCollection).get()).docs.length;

      return {
        'totalOldBeaches': oldCount,
        'totalNewBeaches': newCount,
        'processedCount': processedCount,
        'remainingCount': oldCount - processedCount,
      };
    } catch (e) {
      print('Error getting migration stats: $e');
      return {};
    }
  }

  /// Main migration method with enhanced duplicate detection
  Future<void> migrateAllData({
    Function(String)? onProgress,
    bool generateAiDescriptions = true,
    bool generateAiImages = false,
    int aiImageFrequency = 3,
    bool skipExisting = true,
    int maxItems = 0, // 0 = unlimited
  }) async {
    try {
      resetMigrationState();
      await _loadTrackingCache();

      _log('🚀 Starting migration from $oldCollectionName to $newCollectionName...', onProgress);
      _log('   AI Descriptions: ${generateAiDescriptions ? "✅" : "❌"}', onProgress);
      _log('   AI Images: ${generateAiImages ? "✅ (every ${aiImageFrequency}rd beach)" : "❌"}', onProgress);
      _log('   Skip Existing: ${skipExisting ? "✅" : "❌"}', onProgress);
      if (maxItems > 0) {
        _log('   Max this run: $maxItems beach${maxItems == 1 ? "" : "es"}', onProgress);
      } else {
        _log('   Max this run: ∞ (no limit)', onProgress);
      }

      final QuerySnapshot oldBeaches = await _firestore.collection(oldCollectionName).get();
      _log('📊 Found ${oldBeaches.docs.length} beaches to migrate', onProgress);
      _log('📋 Already processed: ${_processedUuids.length} beaches', onProgress);

      int successCount = 0;
      int errorCount = 0;
      int skippedCount = 0;
      int aiImageCount = 0;

      for (int i = 0; i < oldBeaches.docs.length; i++) {
        if (_shouldStop) {
          _log('🛑 Migration stopped by user at beach ${i + 1}/${oldBeaches.docs.length}', onProgress);
          break;
        }

        while (_isPaused && !_shouldStop) {
          _log('⏸️ Migration paused... (beach ${i + 1}/${oldBeaches.docs.length})', onProgress);
          await Future.delayed(const Duration(milliseconds: 500));
        }
        if (_shouldStop) break;

        // ✅ Enforce per-run cap BEFORE starting next migration
        if (maxItems > 0 && successCount >= maxItems) {
          _log('⛔ Reached max of $maxItems migrated beaches for this run. Stopping.', onProgress);
          break;
        }

        final doc = oldBeaches.docs[i];
        final uuid = doc.id;

        try {
          if (skipExisting) {
            if (await _isDuplicate(uuid, doc.data() as Map<String, dynamic>, onProgress)) {
              skippedCount++;
              continue;
            }
          }

          final shouldGenerateImage = generateAiImages && (successCount % aiImageFrequency == 0);
          if (shouldGenerateImage) aiImageCount++;

          final newBeachId = await _migrateSingleBeach(
            doc,
            generateAiDescription: generateAiDescriptions,
            generateAiImage: shouldGenerateImage,
            onProgress: onProgress,
          );

          // Mark as processed AFTER successful migration
          if (newBeachId != null) {
            final beachName = (doc.data() as Map<String, dynamic>)['name'] ?? 'Unknown';
            await _markAsProcessed(uuid, beachName, newBeachId);
          }

          successCount++;
          _log('[BEACH_DONE] ${i + 1}/${oldBeaches.docs.length} (this run: $successCount)', onProgress);
          _log('✅ Migrated beach ${i + 1}/${oldBeaches.docs.length}: $uuid', onProgress);
        } catch (e) {
          errorCount++;
          _log('❌ Error migrating beach $uuid: $e', onProgress);
        }
      }

      _log('🎉 Migration completed!', onProgress);
      _log('   ✅ Successfully migrated: $successCount beaches', onProgress);
      _log('   ⏭️ Skipped existing: $skippedCount beaches', onProgress);
      _log('   ❌ Errors: $errorCount beaches', onProgress);
      if (generateAiImages) {
        _log('   🎨 AI Images generated: $aiImageCount', onProgress);
        _log('   💰 Estimated cost: \$${(successCount * 0.002 + aiImageCount * 0.040).toStringAsFixed(2)}', onProgress);
      }
    } catch (e) {
      _log('💥 Migration failed: $e', onProgress);
      rethrow;
    }
  }

  /// Modified _migrateSingleBeach to return the new beach ID
  Future<String?> _migrateSingleBeach(
      DocumentSnapshot oldDoc, {
        bool generateAiDescription = true,
        bool generateAiImage = false,
        Function(String)? onProgress,
      }) async {
    final oldData = oldDoc.data() as Map<String, dynamic>;

    // Start with the basic transformed beach
    Beach newBeach = _transformBeachData(oldDoc.id, oldData);

    // Generate AI description if requested
    if (generateAiDescription) {
      _log('🤖 Generating AI description for ${newBeach.name}...', onProgress);
      try {
        final aiDescription = await _geminiService.generateBeachDescription(
          beachName: newBeach.name,
          userAnswers: _extractUserAnswersFromBeach(oldData),
        );

        _log('📝 AI description received (${aiDescription.length} chars)', onProgress);
        newBeach = _createUpdatedBeach(newBeach, aiDescription: aiDescription);
        _log('✅ AI description generated for ${newBeach.name}', onProgress);
      } catch (e) {
        _log('⚠️ Failed to generate AI description for ${newBeach.name}: $e', onProgress);
      }
    }

    // Generate AI image if requested
    if (generateAiImage) {
      _log('🎨 Generating AI image for ${newBeach.name}...', onProgress);
      try {
        final aiImagePrompt = _buildAiImagePrompt(newBeach, oldData);
        _log('🖼️ Sending prompt to AI (${aiImagePrompt.length} chars)', onProgress);

        final aiImageUrl = await _generateAiImageForBeach(newBeach.name, aiImagePrompt);

        if (aiImageUrl.isNotEmpty) {
          _log('📸 AI image received: ${aiImageUrl.substring(0, aiImageUrl.length.clamp(0, 50))}...', onProgress);

          final updatedImageUrls = List<String>.from(newBeach.imageUrls);
          updatedImageUrls.add(aiImageUrl);
          newBeach = _createUpdatedBeach(newBeach, imageUrls: updatedImageUrls);
          _log('✅ AI image generated and added for ${newBeach.name}', onProgress);
        } else {
          _log('⚠️ AI image generation returned empty URL for ${newBeach.name}', onProgress);
        }
      } catch (e) {
        _log('⚠️ Failed to generate AI image for ${newBeach.name}: $e', onProgress);
      }
    }

    // Create the contribution BEFORE saving the beach (to get the contribution data)
    final contribution = Contribution(
      userId: 'migrated_user',
      userEmail: 'migrated@beachbook.app',
      timestamp: _extractTimestamp(oldData, ['timestamp']) ?? Timestamp.now(),
      latitude: _extractDouble(oldData, ['latitude']) ?? 0.0,
      longitude: _extractDouble(oldData, ['longitude']) ?? 0.0,
      contributedImageUrls: newBeach.imageUrls, // Use the final image URLs (including AI)
      localImagePaths: [],
      isSynced: true,
      userAnswers: _extractUserAnswersFromBeach(oldData),
      aiConfirmedFloraFauna: [],
      aiConfirmedRockTypes: [],
    );

    // Update beach with proper contribution count and aggregated data
    // IMPORTANT FIX: Set totalContributions to 0 so the Cloud Function can increment it to 1
    newBeach = _createUpdatedBeach(
      newBeach,
      totalContributions: 0, // Changed from 1 to 0 - let the Cloud Function handle the increment
      aggregatedMetrics: _extractAggregatedMetrics(oldData),
      aggregatedSingleChoices: _extractAggregatedSingleChoices(oldData),
      aggregatedMultiChoices: _extractAggregatedMultiChoices(oldData),
      aggregatedTextItems: _extractAggregatedTextItems(oldData),
    );

    // Save to Firestore using a batch write to ensure atomicity
    _log('💾 Saving beach and contribution to Firestore...', onProgress);

    final batch = _firestore.batch();

    // Add the beach document
    final beachRef = _firestore.collection(newCollectionName).doc();
    batch.set(beachRef, newBeach.toMap());

    // Add the single contribution as a subcollection
    final contributionRef = beachRef.collection('contributions').doc();
    batch.set(contributionRef, contribution.toMap());

    // Commit both at once
    await batch.commit();

    _log('✅ Beach and contribution saved with ID: ${beachRef.id}', onProgress);
    return beachRef.id;
  }

  /// Enhanced _createUpdatedBeach to handle contribution counts and aggregated data
  Beach _createUpdatedBeach(
      Beach originalBeach, {
        String? aiDescription,
        List<String>? imageUrls,
        int? totalContributions,
        Map<String, double>? aggregatedMetrics,
        Map<String, dynamic>? aggregatedSingleChoices,
        Map<String, dynamic>? aggregatedMultiChoices,
        Map<String, List<dynamic>>? aggregatedTextItems,
      }) {
    return Beach(
      id: originalBeach.id,
      name: originalBeach.name,
      latitude: originalBeach.latitude,
      longitude: originalBeach.longitude,
      geohash: originalBeach.geohash,
      country: originalBeach.country,
      province: originalBeach.province,
      municipality: originalBeach.municipality,
      description: originalBeach.description,
      aiDescription: aiDescription ?? originalBeach.aiDescription,
      imageUrls: imageUrls ?? originalBeach.imageUrls,
      contributedDescriptions: originalBeach.contributedDescriptions,
      timestamp: originalBeach.timestamp,
      lastAggregated: originalBeach.lastAggregated,
      totalContributions: totalContributions ?? originalBeach.totalContributions,
      aggregatedMetrics: aggregatedMetrics ?? originalBeach.aggregatedMetrics,
      aggregatedSingleChoices: aggregatedSingleChoices ?? originalBeach.aggregatedSingleChoices,
      aggregatedMultiChoices: aggregatedMultiChoices ?? originalBeach.aggregatedMultiChoices,
      aggregatedTextItems: aggregatedTextItems ?? originalBeach.aggregatedTextItems,
      identifiedFloraFauna: originalBeach.identifiedFloraFauna,
      identifiedRockTypesComposition: originalBeach.identifiedRockTypesComposition,
      identifiedBeachComposition: originalBeach.identifiedBeachComposition,
      discoveryQuestions: originalBeach.discoveryQuestions,
      educationalInfo: originalBeach.educationalInfo,
    );
  }

  /// Test method to check if migration would work for a single document (no write)
  Future<void> testMigration({String? specificDocId, Function(String)? onProgress}) async {
    try {
      Query query = _firestore.collection(oldCollectionName);
      if (specificDocId != null) {
        final doc = await _firestore.collection(oldCollectionName).doc(specificDocId).get();
        if (!doc.exists) {
          _log('❌ Document $specificDocId not found', onProgress);
          return;
        }
        _log('🔍 Testing migration for document: $specificDocId', onProgress);
        final transformedBeach = _transformBeachData(doc.id, doc.data() as Map<String, dynamic>);
        _log('✅ Transformation successful!', onProgress);
        _log('📋 Result preview (NOT SAVED):', onProgress);
        _log('   Name: ${transformedBeach.name}', onProgress);
        _log('   Location: ${transformedBeach.latitude}, ${transformedBeach.longitude}', onProgress);
        _log('   Images: ${transformedBeach.imageUrls.length}', onProgress);
        _log('   Metrics: ${transformedBeach.aggregatedMetrics.length}', onProgress);
        _log('   📝 This was only a test - no data was written to beaches collection', onProgress);
      } else {
        final snapshot = await query.limit(1).get();
        if (snapshot.docs.isEmpty) {
          _log('❌ No documents found in $oldCollectionName', onProgress);
          return;
        }
        final doc = snapshot.docs.first;
        _log('🔍 Testing migration for first document: ${doc.id}', onProgress);
        final transformedBeach = _transformBeachData(doc.id, doc.data() as Map<String, dynamic>);
        _log('✅ Transformation successful!', onProgress);
        _log('📋 Result preview (NOT SAVED):', onProgress);
        _log('   Name: ${transformedBeach.name}', onProgress);
        _log('   Location: ${transformedBeach.latitude}, ${transformedBeach.longitude}', onProgress);
        _log('   Images: ${transformedBeach.imageUrls.length}', onProgress);
        _log('   Metrics: ${transformedBeach.aggregatedMetrics.length}', onProgress);
        _log('   📝 This was only a test - no data was written to beaches collection', onProgress);
      }
    } catch (e) {
      _log('❌ Test migration failed: $e', onProgress);
    }
  }

  /// Test method that actually writes one document to verify the structure
  Future<void> testMigrationWithWrite({
    String? specificDocId,
    Function(String)? onProgress,
    bool generateAiDescription = true,
    bool generateAiImage = false,
    bool skipExisting = true,
  }) async {
    try {
      Query query = _firestore.collection(oldCollectionName);
      DocumentSnapshot doc;

      if (specificDocId != null) {
        doc = await _firestore.collection(oldCollectionName).doc(specificDocId).get();
        if (!doc.exists) {
          _log('❌ Document $specificDocId not found', onProgress);
          return;
        }
        _log('🔍 Testing migration with write for document: $specificDocId', onProgress);
      } else {
        final snapshot = await query.limit(1).get();
        if (snapshot.docs.isEmpty) {
          _log('❌ No documents found in $oldCollectionName', onProgress);
          return;
        }
        doc = snapshot.docs.first;
        _log('🔍 Testing migration with write for first document: ${doc.id}', onProgress);
      }

      // Check for existing beach first if skipExisting is enabled
      if (skipExisting) {
        if (await _isDuplicate(doc.id, doc.data() as Map<String, dynamic>, onProgress)) {
          _log('⏭️ Beach already processed or exists', onProgress);
          return;
        }
      }

      // Use the full migration method with AI options
      final newBeachId = await _migrateSingleBeach(
        doc,
        generateAiDescription: generateAiDescription,
        generateAiImage: generateAiImage,
        onProgress: onProgress,
      );

      // Mark as processed
      if (newBeachId != null) {
        final beachName = (doc.data() as Map<String, dynamic>)['name'] ?? 'Unknown';
        await _markAsProcessed(doc.id, beachName, newBeachId);
      }

      _log('✅ Test beach and contribution created successfully!', onProgress);
      _log('📋 You can now check your beaches collection in Firestore', onProgress);

    } catch (e) {
      _log('❌ Test migration with write failed: $e', onProgress);
      rethrow;
    }
  }

  /// Transform old beach data structure to new Beach model
  Beach _transformBeachData(String oldId, Map<String, dynamic> oldData) {
    final String name = _extractString(oldData, ['name']) ?? 'Unnamed Beach';
    final double latitude = _extractDouble(oldData, ['latitude']) ?? 0.0;
    final double longitude = _extractDouble(oldData, ['longitude']) ?? 0.0;

    final String geohash = latitude != 0.0 && longitude != 0.0
        ? _geoHasher.encode(longitude, latitude, precision: 9)
        : '';

    final String country = _extractString(oldData, ['country']) ?? 'Canada';
    final String province = _extractString(oldData, ['province']) ?? 'Alberta';
    final String municipality = _extractString(oldData, ['municipality']) ?? '';

    final String description = _extractString(oldData, ['description']) ?? '';
    final String aiDescription = '';

    final List<String> imageUrls = _extractStringList(oldData, ['imageUrls']);

    final List<String> contributedDescriptions = [];
    if (description.isNotEmpty) {
      contributedDescriptions.add(description);
    }

    final Timestamp timestamp = _extractTimestamp(oldData, ['timestamp']) ?? Timestamp.now();
    final Timestamp lastAggregated = timestamp;

    final Map<String, double> aggregatedMetrics = _extractAggregatedMetrics(oldData);
    final Map<String, dynamic> aggregatedSingleChoices = _extractAggregatedSingleChoices(oldData);
    final Map<String, dynamic> aggregatedMultiChoices = _extractAggregatedMultiChoices(oldData);
    final Map<String, List<dynamic>> aggregatedTextItems = _extractAggregatedTextItems(oldData);

    final Map<String, dynamic> identifiedFloraFauna = <String, dynamic>{};
    final Map<String, dynamic> identifiedRockTypes = <String, dynamic>{};
    final Map<String, dynamic> identifiedBeachComposition = <String, dynamic>{};

    final List<String> discoveryQuestions = <String>[];
    final String educationalInfo = '';

    // Changed from 1 to 0 to match the fix in _migrateSingleBeach
    final int totalContributions = 0;

    return Beach(
      id: '',
      name: name,
      latitude: latitude,
      longitude: longitude,
      geohash: geohash,
      country: country,
      province: province,
      municipality: municipality,
      description: description,
      aiDescription: aiDescription,
      imageUrls: imageUrls,
      contributedDescriptions: contributedDescriptions,
      timestamp: timestamp,
      lastAggregated: lastAggregated,
      totalContributions: totalContributions,
      aggregatedMetrics: aggregatedMetrics,
      aggregatedSingleChoices: aggregatedSingleChoices,
      aggregatedMultiChoices: aggregatedMultiChoices,
      aggregatedTextItems: aggregatedTextItems,
      identifiedFloraFauna: identifiedFloraFauna,
      identifiedRockTypesComposition: identifiedRockTypes,
      identifiedBeachComposition: identifiedBeachComposition,
      discoveryQuestions: discoveryQuestions,
      educationalInfo: educationalInfo,
    );
  }

  /// Extract user answers from the old beach structure
  Map<String, dynamic> _extractUserAnswersFromBeach(Map<String, dynamic> oldData) {
    final Map<String, dynamic> answers = {};

    final List<String> allFields = [
      'Anemones', 'Barnacles', 'Baseball Rocks', 'Best Tide', 'Birds',
      'Bluff Comp', 'Bluff Grade', 'Bluff Height', 'Boats on Shore',
      'Boulders', 'Bugs', 'Caves', 'Clams', 'Coal', 'Firewood',
      'Garbage', 'Gold', 'Islands', 'Kindling', 'Length', 'Limpets',
      'Logs', 'Lookout', 'Man Made', 'Midden', 'Mud', 'Mussels',
      'New Items', 'Oysters', 'Parking', 'Patio Nearby?', 'Pebbles',
      'People', 'Private', 'Rock Type', 'Rocks', 'Sand', 'Shade',
      'Shape', 'Snails', 'Stink', 'Stone', 'Tree Types', 'Trees',
      'Treasure', 'Turtles', 'Which Shells', 'Width', 'Windy'
    ];

    for (final field in allFields) {
      final value = oldData[field];
      if (value != null) {
        // Convert numeric indices to text for single/multi choice fields
        if (['Best Tide', 'Parking', 'Rock Type', 'Shape'].contains(field) && value is num) {
          String? choiceText;
          switch (field) {
            case 'Best Tide':
              final choices = ['Low', 'Mid', 'High', "Don't Matter"];
              final index = value.toInt();
              if (index >= 0 && index < choices.length) {
                choiceText = choices[index];
              }
              break;
            case 'Parking':
              final choices = ['Parked on the beach', '1 minute', '5 minutes', '10 minutes', '30 minutes', '1 hour plus', 'Boat access only'];
              final index = value.toInt();
              if (index >= 0 && index < choices.length) {
                choiceText = choices[index];
              }
              break;
            case 'Rock Type':
              final choices = ['Igneous', 'Sedimentary', 'Metamorphic'];
              final index = value.toInt();
              if (index >= 0 && index < choices.length) {
                choiceText = choices[index];
              }
              break;
            case 'Shape':
              final choices = ['Concave', 'Convex', 'Isthmus', 'Horseshoe', 'Straight'];
              final index = value.toInt();
              if (index >= 0 && index < choices.length) {
                choiceText = choices[index];
              }
              break;
          }
          if (choiceText != null) {
            answers[field] = choiceText;
          }
        } else {
          answers[field] = value;
        }
      }
    }

    final description = _extractString(oldData, ['description']);
    if (description != null) {
      answers['Short Description'] = description;
    }

    return answers;
  }

  /// Find existing beach by name and location to avoid duplicates
  Future<Beach?> _findExistingBeach(Map<String, dynamic> oldData) async {
    final String name = _extractString(oldData, ['name']) ?? '';
    final double latitude = _extractDouble(oldData, ['latitude']) ?? 0.0;
    final double longitude = _extractDouble(oldData, ['longitude']) ?? 0.0;

    if (name.isEmpty || latitude == 0.0 || longitude == 0.0) return null;

    try {
      final QuerySnapshot nameQuery = await _firestore
          .collection(newCollectionName)
          .where('name', isEqualTo: name)
          .limit(5)
          .get();

      for (final doc in nameQuery.docs) {
        final beach = Beach.fromFirestore(doc);
        final distance = _calculateDistance(
            latitude, longitude,
            beach.latitude, beach.longitude
        );
        if (distance < 0.1) {
          return beach;
        }
      }
      return null;
    } catch (e) {
      print('Error checking for existing beach: $e');
      return null;
    }
  }

  /// Generate AI image for a beach using the same approach as add_beach_screen
  Future<String> _generateAiImageForBeach(String beachName, String prompt) async {
    try {
      final geminiInfo = await _geminiService.getInfoAndImage(beachName, description: prompt);
      return geminiInfo.imageUrl;
    } catch (e) {
      print('Error generating AI image: $e');
      return '';
    }
  }

  /// Build AI image prompt similar to add_beach_screen
  String _buildAiImagePrompt(Beach beach, Map<String, dynamic> oldData) {
    final parts = <String>[];

    final beachName = beach.name.trim();
    final whereBits = [
      beach.municipality.trim(),
      beach.province.trim(),
      beach.country.trim(),
    ].where((s) => s.isNotEmpty).join(', ');

    if (beachName.isNotEmpty) {
      parts.add('Photorealistic coastal landscape of "$beachName".');
    }
    if (whereBits.isNotEmpty) {
      parts.add('Location: $whereBits.');
    }

    final short = beach.description.trim();
    if (short.isNotEmpty) parts.add('User notes: $short.');

    String lvl(num v) {
      if (v <= 1) return 'none';
      if (v <= 2) return 'a little';
      if (v <= 3) return 'some';
      if (v <= 4) return 'moderate';
      if (v <= 5) return 'a lot';
      return 'abundant';
    }

    void addIfNum(String label, String pretty) {
      final raw = beach.aggregatedMetrics[label];
      if (raw != null && raw > 1) {
        parts.add('$pretty: ${lvl(raw)}.');
      }
    }

    addIfNum('Sand', 'Sand');
    addIfNum('Pebbles', 'Pebbles');
    addIfNum('Rocks', 'Rocks');
    addIfNum('Baseball Rocks', 'Baseball-sized rocks');
    addIfNum('Boulders', 'Boulders');
    addIfNum('Stone', 'Stone');
    addIfNum('Mud', 'Mud');
    addIfNum('Coal', 'Coal fragments');
    addIfNum('Midden', 'Shell midden');
    addIfNum('Islands', 'Nearby islets');
    addIfNum('Seaweed Beach', 'Washed-up seaweed on beach');
    addIfNum('Seaweed Rocks', 'Seaweed on intertidal rocks');
    addIfNum('Kelp Beach', 'Kelp on shore');
    addIfNum('Kindling', 'Small driftwood');
    addIfNum('Firewood', 'Driftwood');
    addIfNum('Logs', 'Large logs');
    addIfNum('Trees', 'Trees near shore');

    void addIfText(String label, String prefix) {
      final choices = beach.aggregatedSingleChoices[label];
      if (choices is Map<String, dynamic> && choices.isNotEmpty) {
        final topChoice = choices.entries.first.key;
        parts.add('$prefix $topChoice.');
      }
    }

    addIfText('Rock Type', 'Dominant rock type:');
    addIfText('Shape', 'Shoreline shape:');

    parts.addAll([
      'Time of day neutral; natural colors; no people; no text or logos.',
      'Angle: eye-level to slight wide angle; weather fair and believable.',
      'Only include features listed above; avoid adding structures or elements not specified.',
    ]);

    return parts.join(' ');
  }

  /// Calculate distance between two points in kilometers
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180);

  // Helper methods for data extraction
  String? _extractString(Map<String, dynamic> data, List<String> possibleKeys) {
    for (final key in possibleKeys) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }

  double? _extractDouble(Map<String, dynamic> data, List<String> possibleKeys) {
    for (final key in possibleKeys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  List<String> _extractStringList(Map<String, dynamic> data, List<String> possibleKeys) {
    for (final key in possibleKeys) {
      final value = data[key];
      if (value is List) {
        return value.where((item) => item is String).cast<String>().toList();
      }
      if (value is String && value.isNotEmpty) {
        return value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      }
    }
    return [];
  }

  Timestamp? _extractTimestamp(Map<String, dynamic> data, List<String> possibleKeys) {
    for (final key in possibleKeys) {
      final value = data[key];
      if (value is Timestamp) return value;
      if (value is int) return Timestamp.fromMillisecondsSinceEpoch(value);
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return Timestamp.fromDate(parsed);
      }
    }
    return null;
  }

  /// Extract aggregated metrics - FIXED to avoid duplicates
  Map<String, double> _extractAggregatedMetrics(Map<String, dynamic> data) {
    final Map<String, double> metrics = {};

    // Define ONLY the fields that should be treated as numeric metrics
    // Explicitly EXCLUDE single/multi-choice fields to prevent duplicates
    final List<String> singleChoiceFields = ['Best Tide', 'Parking', 'Rock Type', 'Shape'];
    final List<String> multiChoiceFields = ['Bluff Comp', 'Man Made', 'Shade', 'Which Shells'];
    final Set<String> excludedFields = {...singleChoiceFields, ...multiChoiceFields};

    final List<String> numericFields = [
      'Anemones', 'Barnacles', 'Baseball Rocks', 'Bluff Grade',
      'Bluff Height', 'Boats on Shore', 'Boulders', 'Bugs', 'Caves', 'Clams',
      'Coal', 'Firewood', 'Garbage', 'Gold', 'Islands', 'Kindling', 'Length',
      'Limpets', 'Logs', 'Lookout', 'Midden', 'Mud', 'Mussels', 'Oysters',
      'Patio Nearby?', 'Pebbles', 'People', 'Private', 'Rocks', 'Sand',
      'Snails', 'Stink', 'Stone', 'Trees', 'Turtles', 'Width', 'Windy',
      // Add seaweed/kelp fields that are numeric sliders in the new system
      'Seaweed Beach', 'Seaweed Rocks', 'Kelp Beach',
    ];

    for (final field in numericFields) {
      // Double-check: only add if not in excluded fields
      if (!excludedFields.contains(field)) {
        final value = data[field];
        if (value is num) {
          metrics[field] = value.toDouble();
        }
      }
    }

    return metrics;
  }

  /// Extract aggregated single choices - FIXED to handle conversions properly
  Map<String, dynamic> _extractAggregatedSingleChoices(Map<String, dynamic> data) {
    final Map<String, dynamic> singleChoices = {};

    // These are the fields that should be treated as single choices
    final List<String> singleChoiceFields = [
      'Best Tide', 'Parking', 'Rock Type', 'Shape'
    ];

    for (final field in singleChoiceFields) {
      final value = data[field];
      if (value is String && value.isNotEmpty) {
        singleChoices[field] = {value: 0};
      } else if (value is num) {
        // Handle case where old data stored these as numbers (indices)
        // You'll need to map these based on your old app's choice arrays
        String? choiceText;
        switch (field) {
          case 'Best Tide':
            final choices = ['Low', 'Mid', 'High', "Don't Matter"];
            final index = value.toInt();
            if (index >= 0 && index < choices.length) {
              choiceText = choices[index];
            }
            break;
          case 'Parking':
            final choices = ['Parked on the beach', '1 minute', '5 minutes', '10 minutes', '30 minutes', '1 hour plus', 'Boat access only'];
            final index = value.toInt();
            if (index >= 0 && index < choices.length) {
              choiceText = choices[index];
            }
            break;
          case 'Rock Type':
            final choices = ['Igneous', 'Sedimentary', 'Metamorphic'];
            final index = value.toInt();
            if (index >= 0 && index < choices.length) {
              choiceText = choices[index];
            }
            break;
          case 'Shape':
            final choices = ['Concave', 'Convex', 'Isthmus', 'Horseshoe', 'Straight'];
            final index = value.toInt();
            if (index >= 0 && index < choices.length) {
              choiceText = choices[index];
            }
            break;
        }
        if (choiceText != null) {
          singleChoices[field] = {choiceText: 1};
        }
      }
    }

    return singleChoices;
  }

  Map<String, dynamic> _extractAggregatedMultiChoices(Map<String, dynamic> data) {
    final Map<String, dynamic> multiChoices = {};

    multiChoiceOptions.forEach((field, possibleValues) {
      final value = data[field];
      if (value is Map<String, dynamic>) {
        final Map<String, int> choices = {};
        value.forEach((index, count) {
          final int? idx = int.tryParse(index);
          if (idx != null && idx < possibleValues.length && count is num && count > 0) {
            choices[possibleValues[idx]] = count.toInt();
          }
        });
        if (choices.isNotEmpty) {
          multiChoices[field] = choices;
        }
      }
    });

    return multiChoices;
  }

  Map<String, List<dynamic>> _extractAggregatedTextItems(Map<String, dynamic> data) {
    final Map<String, List<dynamic>> textItems = {};

    final List<String> textFields = [
      'Birds', 'Tree Types', 'Treasure', 'New Items'
    ];

    for (final field in textFields) {
      final value = data[field];
      if (value is Map<String, dynamic>) {
        final List<String> items = [];
        value.forEach((index, text) {
          if (text is String && text.isNotEmpty) {
            items.add(text);
          }
        });
        if (items.isNotEmpty) {
          textItems[field] = items;
        }
      } else if (value is String && value.isNotEmpty) {
        textItems[field] = [value];
      }
    }

    return textItems;
  }

  // Helper method for logging
  void _log(String message, Function(String)? onProgress) {
    print(message);
    onProgress?.call(message);
  }
}