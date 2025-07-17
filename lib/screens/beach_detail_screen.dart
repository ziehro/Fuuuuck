// lib/screens/beach_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fuuuuck/models/beach_model.dart';
import 'package:fuuuuck/services/beach_data_service.dart';
import 'package:fuuuuck/screens/add_beach_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fuuuuck/services/api/inaturalist_service.dart'; // ** NEW: Import iNaturalistService **

class BeachDetailScreen extends StatelessWidget {
  final String beachId;

  const BeachDetailScreen({super.key, required this.beachId});

  // ** NEW: Function to show the details dialog **
  void _showFloraFaunaDetailsDialog(BuildContext context, String name, Map<String, dynamic> details) {
    final String imageUrl = details['imageUrl'] ?? '';
    final int taxonId = details['taxonId'] ?? 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(name),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imageUrl.isNotEmpty)
                  Image.network(
                    imageUrl,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                const SizedBox(height: 16),
                FutureBuilder<Map<String, dynamic>?>(
                  future: INaturalistService().getTaxonDetails(taxonId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                      return const Text('Could not load educational info.');
                    }
                    final taxonDetails = snapshot.data!;
                    final blurb = taxonDetails['wikipedia_summary'] ?? 'No educational blurb available.';
                    return Text(blurb);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final beachDataService = Provider.of<BeachDataService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beach Details'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: FutureBuilder<Beach?>(
        future: beachDataService.getBeachById(beachId), // Fetch a single beach
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Center(child: Text('Error or Beach not found: ${snapshot.error}'));
          }

          final Beach beach = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Display main beach photo
                if (beach.imageUrls.isNotEmpty)
                  Image.network(
                    beach.imageUrls.first,
                    fit: BoxFit.cover,
                    height: 250,
                  ),

                // Main Info Card
                Card(
                  margin: const EdgeInsets.all(16.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          beach.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${beach.municipality}, ${beach.province}, ${beach.country}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          beach.description,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),

                // ** NEW: Contribute Button moved higher for visibility **
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigates to AddBeachScreen with the beachId and location
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddBeachScreen(
                            beachId: beach.id,
                            initialLocation: LatLng(beach.latitude, beach.longitude),
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Add Your Contribution'),
                  ),
                ),

                // Aggregated Data Tabs
                DefaultTabController(
                  length: 2, // For "Current Data" and "Educational"
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'Current Data'),
                          Tab(text: 'Educational Info'),
                        ],
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).size.height, // Adjust height as needed
                        child: TabBarView(
                          children: [
                            // 1. Current Data Tab
                            _buildCurrentDataTab(context, beach),

                            // 2. Educational Info Tab
                            _buildEducationalInfoTab(context, beach),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper function to build the Current Data tab content
  Widget _buildCurrentDataTab(BuildContext context, Beach beach) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display Aggregated Metrics (Sliders, Numbers)
          _buildCategoryTitle(context, 'General Metrics'),
          ...beach.aggregatedMetrics.entries.map((entry) => _buildDataRow(entry.key, entry.value.toStringAsFixed(2))),
          const SizedBox(height: 16),

          // Display Aggregated Single Choices
          _buildCategoryTitle(context, 'Single-Choice Answers'),
          ...beach.aggregatedSingleChoices.entries.map((entry) => _buildDataRow(entry.key, entry.value)),
          const SizedBox(height: 16),

          // Display Aggregated Multi-Choices
          _buildCategoryTitle(context, 'Multi-Choice Answers'),
          ...beach.aggregatedMultiChoices.entries.map((entry) => _buildDataRow(entry.key, entry.value.join(', '))),
          const SizedBox(height: 16),

          // Display Aggregated Text Items
          _buildCategoryTitle(context, 'Text Submissions'),
          ...beach.aggregatedTextItems.entries.map((entry) => _buildDataRow(entry.key, entry.value.join(', '))),
          const SizedBox(height: 16),

          // ** NEW: Updated Flora & Fauna display with long press **
          _buildCategoryTitle(context, 'AI Identified Flora & Fauna'),
          ...beach.identifiedFloraFauna.entries.map((entry) {
            return GestureDetector(
              onLongPress: () => _showFloraFaunaDetailsDialog(context, entry.key, entry.value),
              child: _buildDataRow(entry.key, entry.value['count'].toString()),
            );
          }),
          const SizedBox(height: 16),

          // Display AI Identified Rock/Beach Composition
          _buildCategoryTitle(context, 'AI Identified Composition'),
          ...beach.identifiedRockTypesComposition.entries.map((entry) => _buildDataRow(entry.key, entry.value.toStringAsFixed(2))),
          ...beach.identifiedBeachComposition.entries.map((entry) => _buildDataRow(entry.key, entry.value.toStringAsFixed(2))),
          const SizedBox(height: 16),

          _buildCategoryTitle(context, 'Contribution Summary'),
          _buildDataRow('Total Contributions', beach.totalContributions.toString()),
          _buildDataRow('Last Updated', beach.lastAggregated.toDate().toLocal().toString().split('.')[0]),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Helper function to build the Educational Info tab content
  Widget _buildEducationalInfoTab(BuildContext context, Beach beach) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryTitle(context, 'Educational Information'),
          Text(
            beach.educationalInfo.isNotEmpty ? beach.educationalInfo : 'No educational information available for this beach yet.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          _buildCategoryTitle(context, 'Discovery Scavenger Hunt'),
          ...beach.discoveryQuestions.map((question) => Text('- $question', style: Theme.of(context).textTheme.bodyMedium)),
          if (beach.discoveryQuestions.isEmpty)
            Text('No scavenger hunt questions for this beach yet.', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  // Helper widgets for consistent styling
  Widget _buildCategoryTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
    );
  }

  Widget _buildDataRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$key:', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}