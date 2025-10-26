// lib/screens/beach_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mybeachbook/models/beach_model.dart';
import 'package:mybeachbook/services/beach_data_service.dart';
import 'package:mybeachbook/screens/add_beach_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mybeachbook/services/api/inaturalist_service.dart';
import 'package:mybeachbook/util/metric_ranges.dart';
import 'package:mybeachbook/services/gemini_service.dart';
import 'package:mybeachbook/util/long_press_descriptions.dart';
import 'package:mybeachbook/widgets/fullscreen_image_viewer.dart';
import 'package:mybeachbook/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:mybeachbook/util/constants.dart';

class BeachDetailScreen extends StatelessWidget {
  final String beachId;

  static const List<String> _adminUserIds = AppConstants.adminUserIds;

  const BeachDetailScreen({super.key, required this.beachId});

  // --- Metric Category Keys ---
  static const List<String> floraMetricKeys = [
    'Kelp Beach', 'Seaweed Beach', 'Seaweed Rocks'
  ];
  // Fixed order: kindling -> firewood -> logs -> trees
  static const List<String> woodMetricKeys = [
    'Kindling', 'Firewood', 'Logs', 'Trees'
  ];
  // Alphabetized
  static const List<String> faunaMetricKeys = [
    'Anemones', 'Barnacles', 'Bugs', 'Clams', 'Limpets', 'Mussels', 'Oysters', 'Snails', 'Turtles'
  ];
  static const List<String> compositionOrderedKeys = [
    'Width', 'Length', 'Sand', 'Pebbles', 'Baseball Rocks', 'Rocks', 'Boulders', 'Stone', 'Coal', 'Mud', 'Midden', 'Islands', 'Bluff Height', 'Bluffs Grade'
  ];
  // --- End of Keys ---

  void _showInfoDialog(BuildContext context, String subject) {
    final GeminiService geminiService = GeminiService();
    final String description = longPressDescriptions[subject] ?? 'No description available.';

    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<GeminiInfo>(
          future: geminiService.getInfoAndImage(subject, description: description),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading info...'),
                  ],
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return AlertDialog(
                title: const Text('Error'),
                content: const Text('Could not load information.'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
                ],
              );
            }

            final info = snapshot.data!;
            return AlertDialog(
              title: Text(subject),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: info.image,
                    ),
                    const SizedBox(height: 16),
                    Text(info.description),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
              ],
            );
          },
        );
      },
    );
  }

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
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 150),
                  ),
                const SizedBox(height: 16),
                FutureBuilder<Map<String, dynamic>?>(
                  future: INaturalistService().getTaxonDetails(taxonId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                      return const Text('Could not load educational info.');
                    }
                    final taxonDetails = snapshot.data!;
                    final blurb = taxonDetails['wikipedia_summary'] ?? 'No educational blurb available.';
                    return Text(blurb, style: Theme.of(context).textTheme.bodyMedium);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showEducationalInfoDialog(BuildContext context, Beach beach) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Educational Information'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(beach.educationalInfo.isNotEmpty ? beach.educationalInfo : 'No educational information available yet.', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 24),
                  _buildCategoryTitle(context, 'Discovery Scavenger Hunt'),
                  if (beach.discoveryQuestions.isEmpty)
                    Text('No scavenger hunt questions for this beach yet.', style: Theme.of(context).textTheme.bodyMedium)
                  else
                    ...beach.discoveryQuestions.map((question) => ListTile(leading: const Icon(Icons.explore), title: Text(question))),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        });
  }

  void _copyBeachIdToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: beachId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Beach ID copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showDeleteImageDialog(BuildContext context, String beachId, List<String> imageUrls) async {
    if (imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No images to delete'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show selection dialog
    final selectedIndex = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.image, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Select Image to Delete'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Image.network(
                    imageUrls[index],
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, size: 60),
                  ),
                  title: Text('Image ${index + 1}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, index),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedIndex == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Delete Image?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action is PERMANENT and cannot be undone!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 16),
            Text('Delete image #${selectedIndex + 1} from this beach?'),
            const SizedBox(height: 8),
            const Text('The image will be permanently deleted from storage.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('DELETE IMAGE'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _deleteImage(context, beachId, imageUrls[selectedIndex]);
    }
  }

  Future<void> _deleteImage(BuildContext context, String beachId, String imageUrl) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Deleting image...'),
          ],
        ),
      ),
    );

    try {
      final beachDataService = Provider.of<BeachDataService>(context, listen: false);
      await beachDataService.deleteBeachImage(beachId, imageUrl);

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteBeachDialog(BuildContext context, String beachId, String beachName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Delete Beach?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action is PERMANENT and cannot be undone!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            const Text('The following will be deleted:'),
            const SizedBox(height: 8),
            Text('• Beach: $beachName'),
            const Text('• All contributions'),
            const Text('• All images from storage'),
            const SizedBox(height: 16),
            const Text(
              'Are you absolutely sure?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('DELETE PERMANENTLY'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _deleteBeach(context, beachId);
    }
  }

  Future<void> _deleteBeach(BuildContext context, String beachId) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Deleting beach...'),
          ],
        ),
      ),
    );

    try {
      final beachDataService = Provider.of<BeachDataService>(context, listen: false);
      await beachDataService.deleteBeach(beachId);

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Beach deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to map
        Navigator.pop(context);
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete beach: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool get _isAdmin {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && _adminUserIds.contains(currentUser.uid);
  }

  @override
  Widget build(BuildContext context) {
    final beachDataService = Provider.of<BeachDataService>(context);

    return Scaffold(
      body: FutureBuilder<Beach?>(
        future: beachDataService.getBeachById(beachId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Center(child: Text('Error or Beach not found: ${snapshot.error}'));
          }

          final beach = snapshot.data!;
          final dataTabs = _buildDataTabs(context, beach);

          return DefaultTabController(
            length: dataTabs.keys.length,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 350.0,
                    floating: false,
                    pinned: true,
                    leading: const BackButton(),
                    actions: _isAdmin
                        ? [
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: IconButton(
                          icon: const Icon(Icons.info_outline, color: Colors.white),
                          tooltip: 'Beach ID (tap to copy)',
                          onPressed: () {
                            _copyBeachIdToClipboard(context);
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Row(
                                  children: [
                                    Icon(Icons.admin_panel_settings, color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text('Beach ID'),
                                  ],
                                ),
                                content: SelectableText(
                                  beachId,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      _copyBeachIdToClipboard(context);
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Copy & Close'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.image, color: Colors.orange, size: 20),
                              tooltip: 'Delete Image',
                              onPressed: () => _showDeleteImageDialog(context, beachId, beach.imageUrls),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                            ),
                            const Text(
                              'Image',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 7,
                                fontWeight: FontWeight.w500,
                                height: 0.9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_forever, color: Colors.red, size: 20),
                              tooltip: 'Delete Beach',
                              onPressed: () => _showDeleteBeachDialog(context, beachId, beach.name),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              visualDensity: VisualDensity.compact,
                            ),
                            const Text(
                              'Beach',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 7,
                                fontWeight: FontWeight.w500,
                                height: 0.9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ]
                        : null,
                    flexibleSpace: FlexibleSpaceBar(
                      background: ImageDescriptionCarousel(
                        imageUrls: beach.imageUrls,
                        descriptions: beach.contributedDescriptions,
                        contributionCount: beach.totalContributions,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              beach.name,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Chip(
                            avatar: const Icon(Icons.people, size: 18),
                            label: Text(
                              '${beach.totalContributions}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                            side: BorderSide(
                              color: Theme.of(context).primaryColor.withOpacity(0.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add_location_alt),
                              label: const Text('Contribute'),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddBeachScreen(
                                    beachId: beach.id,
                                    initialLocation: LatLng(beach.latitude, beach.longitude),
                                  ),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.school),
                              label: const Text('Education'),
                              onPressed: () => _showEducationalInfoDialog(context, beach),
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        isScrollable: true,
                        tabs: dataTabs.keys.map((title) => Tab(text: title)).toList(),
                      ),
                    ),
                    pinned: true,
                  ),
                ];
              },
              body: TabBarView(
                children: dataTabs.values.toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Map<String, Widget> _buildDataTabs(BuildContext context, Beach beach) {
    return {
      'Basic': _buildBasicTab(context, beach),
      'Flora': _buildFloraTab(context, beach),
      'Fauna': _buildFaunaTab(context, beach),
      'Driftwood': _buildWoodTab(context, beach),
      'Composition': _buildCompositionTab(context, beach),
      'Other': _buildOtherTab(context, beach),
      'Identifications': _buildIdTab(context, beach),
    };
  }

  Widget _buildBasicTab(BuildContext context, Beach beach) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryTitle(context, 'AI Generated Description'),
          Text(beach.aiDescription.isNotEmpty ? beach.aiDescription : 'No AI description available yet.'),
          const SizedBox(height: 24),
          _buildCategoryTitle(context, 'User Contributed Descriptions'),
          if (beach.contributedDescriptions.isEmpty)
            const Text('No user descriptions contributed yet.')
          else
            ...beach.contributedDescriptions.map((desc) => Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text('"$desc"'),
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildFloraTab(BuildContext context, Beach beach) {
    final hasMetrics = floraMetricKeys.any((key) {
      final value = beach.aggregatedMetrics[key];
      if (value == null) return false;
      final range = metricRanges[key];
      final minThreshold = range?.min.toDouble() ?? 0.0;
      return value > minThreshold;
    });

    final hasTreeTypes = beach.aggregatedTextItems.containsKey('Tree types') &&
        (beach.aggregatedTextItems['Tree types'] as List).isNotEmpty;

    if (!hasMetrics && !hasTreeTypes) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.eco, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No flora data yet',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Be the first to contribute!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricsCategoryTab(context, beach, floraMetricKeys),
          if (hasTreeTypes) ...[
            const SizedBox(height: 16),
            _buildCategoryTitle(context, 'Answers'),
            _buildDataRow(
              context,
              'Tree types',
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: (beach.aggregatedTextItems['Tree types'] as List<dynamic>).map((e) => Text(e.toString(), textAlign: TextAlign.end)).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFaunaTab(BuildContext context, Beach beach) {
    final hasMetrics = faunaMetricKeys.any((key) {
      final value = beach.aggregatedMetrics[key];
      if (value == null) return false;
      final range = metricRanges[key];
      final minThreshold = range?.min.toDouble() ?? 0.0;
      return value > minThreshold;
    });

    final hasBirds = beach.aggregatedTextItems.containsKey('Birds') &&
        (beach.aggregatedTextItems['Birds'] as List).isNotEmpty;
    final hasShells = beach.aggregatedMultiChoices.containsKey('Which Shells') &&
        (beach.aggregatedMultiChoices['Which Shells'] as Map).isNotEmpty;

    if (!hasMetrics && !hasBirds && !hasShells) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pets, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No fauna data yet',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Be the first to contribute!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricsCategoryTab(context, beach, faunaMetricKeys),
          if (hasBirds || hasShells) ...[
            const SizedBox(height: 16),
            _buildCategoryTitle(context, 'Answers'),
          ],
          if (hasBirds)
            _buildDataRow(
              context,
              'Birds',
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: (beach.aggregatedTextItems['Birds'] as List<dynamic>).map((e) => Text(e.toString(), textAlign: TextAlign.end)).toList(),
              ),
            ),
          if (hasShells)
            _buildDataRow(
              context,
              'Which Shells',
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: (beach.aggregatedMultiChoices['Which Shells'] as Map<String, dynamic>).entries.map((e) => Text('${e.key}: ${e.value}')).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWoodTab(BuildContext context, Beach beach) {
    final hasMetrics = woodMetricKeys.any((key) {
      final value = beach.aggregatedMetrics[key];
      if (value == null) return false;
      final range = metricRanges[key];
      final minThreshold = range?.min.toDouble() ?? 0.0;
      return value > minThreshold;
    });

    if (!hasMetrics) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.park, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No driftwood data yet',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Be the first to contribute!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: _buildMetricsCategoryTab(context, beach, woodMetricKeys),
    );
  }

  Widget _buildCompositionTab(BuildContext context, Beach beach) {
    final List<String> remainingCompositionKeys = List.from(compositionOrderedKeys)
      ..remove('Width')
      ..remove('Length');

    final hasWidthOrLength = (beach.aggregatedMetrics['Width'] ?? 0) > 0 ||
        (beach.aggregatedMetrics['Length'] ?? 0) > 0;

    final hasOtherComposition = remainingCompositionKeys.any((key) {
      final value = beach.aggregatedMetrics[key];
      if (value == null) return false;
      final range = metricRanges[key];
      final minThreshold = range?.min.toDouble() ?? 0.0;
      return value > minThreshold;
    });

    final hasShapeData = beach.aggregatedSingleChoices.containsKey('Shape') &&
        (beach.aggregatedSingleChoices['Shape'] as Map).isNotEmpty;
    final hasBluffCompData = beach.aggregatedMultiChoices.containsKey('Bluff Comp') &&
        (beach.aggregatedMultiChoices['Bluff Comp'] as Map).isNotEmpty;
    final hasRockTypeData = beach.aggregatedSingleChoices.containsKey('Rock Type') &&
        (beach.aggregatedSingleChoices['Rock Type'] as Map).isNotEmpty;

    if (!hasWidthOrLength && !hasOtherComposition && !hasShapeData && !hasBluffCompData && !hasRockTypeData) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.terrain, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No composition data yet',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Be the first to contribute!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDimensionsRow(context, beach),
          _buildMetricsCategoryTab(context, beach, remainingCompositionKeys, isComposition: true),
          if (hasShapeData || hasBluffCompData || hasRockTypeData) ...[
            const SizedBox(height: 16),
            _buildCategoryTitle(context, 'Answers'),
          ],
          if (hasShapeData)
            _buildDataRow(
              context,
              'Shape',
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: (beach.aggregatedSingleChoices['Shape'] as Map<String, dynamic>).entries.map((e) => Text('${e.key}: ${e.value}')).toList(),
              ),
            ),
          if (hasBluffCompData)
            _buildDataRow(
              context,
              'Bluff Comp',
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: (beach.aggregatedMultiChoices['Bluff Comp'] as Map<String, dynamic>).entries.map((e) => Text('${e.key}: ${e.value}')).toList(),
              ),
            ),
          if (hasRockTypeData)
            _buildDataRow(
              context,
              'Rock Type',
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: (beach.aggregatedSingleChoices['Rock Type'] as Map<String, dynamic>).entries.map((e) => Text('${e.key}: ${e.value}')).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDimensionsRow(BuildContext context, Beach beach) {
    final bool hasWidth = beach.aggregatedMetrics.containsKey('Width') &&
        (beach.aggregatedMetrics['Width'] ?? 0) > 0;
    final bool hasLength = beach.aggregatedMetrics.containsKey('Length') &&
        (beach.aggregatedMetrics['Length'] ?? 0) > 0;

    if (!hasWidth && !hasLength) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (hasWidth)
          Expanded(
            child: GestureDetector(
              onLongPress: () => _showInfoDialog(context, 'Width'),
              child: _buildDimensionBar(
                label: 'Width',
                value: beach.aggregatedMetrics['Width']!,
                unit: 'steps',
              ),
            ),
          ),
        if (hasWidth && hasLength) const SizedBox(width: 8),
        if (hasLength)
          Expanded(
            child: GestureDetector(
              onLongPress: () => _showInfoDialog(context, 'Length'),
              child: _buildDimensionBar(
                label: 'Length',
                value: beach.aggregatedMetrics['Length']!,
                unit: 'steps',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDimensionBar({
    required String label,
    required double value,
    required String unit,
  }) {
    final double visualMax = 1000.0;
    final double percentage = (value / visualMax).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${value.toStringAsFixed(0)} $unit', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: Colors.grey[300],
              ),
              child: FractionallySizedBox(
                widthFactor: percentage > 0.05 ? percentage : 0.05,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: seafoamGreen,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherTab(BuildContext context, Beach beach) {
    final otherSingleChoiceAnswers = Map.from(beach.aggregatedSingleChoices)..removeWhere((key, value) => ['Shape', 'Rock Type'].contains(key));
    final otherMultiChoiceAnswers = Map.from(beach.aggregatedMultiChoices)..removeWhere((key, value) => ['Which Shells', 'Bluff Comp'].contains(key));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricsCategoryTab(context, beach, [], includeOther: true),
          const SizedBox(height: 16),
          _buildCategoryTitle(context, 'Answers'),
          ...otherSingleChoiceAnswers.entries.map<Widget>((entry) {
            final choices = (entry.value as Map<String, dynamic>).entries.toList()..sort((a, b) => (b.value as int).compareTo(a.value as int));
            final answerWidgets = choices.map<Widget>((choice) => Text('${choice.key}: ${choice.value}')).toList();
            return _buildDataRow(context, entry.key, Column(crossAxisAlignment: CrossAxisAlignment.end, children: answerWidgets));
          }).toList(),
          ...otherMultiChoiceAnswers.entries.map<Widget>((entry) {
            final choices = (entry.value as Map<String, dynamic>).entries.toList()..sort((a, b) => (b.value as int).compareTo(a.value as int));
            final answerWidgets = choices.map<Widget>((choice) => Text('${choice.key}: ${choice.value}')).toList();
            return _buildDataRow(context, entry.key, Column(crossAxisAlignment: CrossAxisAlignment.end, children: answerWidgets));
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMetricsCategoryTab(BuildContext context, Beach beach, List<String> keys, {bool includeOther = false, bool isComposition = false}) {
    final Map<String, double> filteredMetrics = {};

    if (includeOther) {
      final allKnownKeys = [...floraMetricKeys, ...faunaMetricKeys, ...compositionOrderedKeys, ...woodMetricKeys];
      beach.aggregatedMetrics.forEach((key, value) {
        if (!allKnownKeys.contains(key)) {
          final range = metricRanges[key];
          final minThreshold = range?.min.toDouble() ?? 0.0;
          if (value > minThreshold) {
            filteredMetrics[key] = value;
          }
        }
      });
    } else {
      for (final key in keys) {
        final v = beach.aggregatedMetrics[key];
        if (v != null) {
          final range = metricRanges[key];
          final minThreshold = range?.min.toDouble() ?? 0.0;

          if (v > minThreshold) {
            filteredMetrics[key] = v;
          }
        }
      }
    }

    if (filteredMetrics.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Text(
          'No significant data for this category yet.',
          style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: filteredMetrics.entries.map((entry) {
        final range = metricRanges[entry.key];
        if (range != null) {
          return GestureDetector(
            onLongPress: () => _showInfoDialog(context, entry.key),
            child: MetricScaleBar(
              label: entry.key,
              value: entry.value,
              min: range.min.toDouble(),
              max: range.max.toDouble(),
            ),
          );
        }
        return _buildDataRow(context, entry.key, Text(entry.value.toStringAsFixed(2), textAlign: TextAlign.end));
      }).toList(),
    );
  }

  Widget _buildIdTab(BuildContext context, Beach beach) {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCategoryTitle(context, 'AI Identified Flora & Fauna'),
            if (beach.identifiedFloraFauna.isEmpty)
              const Text('No flora or fauna identified yet.')
            else
              ...beach.identifiedFloraFauna.entries.map((entry) {
                return InkWell(
                  onLongPress: () => _showFloraFaunaDetailsDialog(context, entry.key, entry.value),
                  child: _buildDataRow(context, entry.key, Text('Count: ${entry.value['count']}', textAlign: TextAlign.end)),
                );
              }),
          ],
        ));
  }

  Widget _buildCategoryTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }

  Widget _buildDataRow(BuildContext context, String key, Widget value) {
    return GestureDetector(
      onLongPress: () => _showInfoDialog(context, key),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(flex: 2, child: Text(key, style: const TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 3, child: value),
            ],
          ),
        ),
      ),
    );
  }
}

class ImageDescriptionCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final List<String> descriptions;
  final int contributionCount;

  const ImageDescriptionCarousel({
    super.key,
    required this.imageUrls,
    required this.descriptions,
    required this.contributionCount,
  });

  @override
  State<ImageDescriptionCarousel> createState() => _ImageDescriptionCarouselState();
}

class _ImageDescriptionCarouselState extends State<ImageDescriptionCarousel> {
  int _currentPage = 0;

  void _openFullScreenViewer(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageUrls: widget.imageUrls,
          initialIndex: initialIndex,
          descriptions: widget.descriptions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 350,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            onPageChanged: (value) {
              setState(() {
                _currentPage = value;
              });
            },
            itemCount: widget.imageUrls.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _openFullScreenViewer(index),
                child: Hero(
                  tag: 'beach_image_$index',
                  child: Image.network(
                    widget.imageUrls[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) =>
                    const Center(
                      child: Icon(Icons.broken_image,
                          size: 100,
                          color: Colors.grey),
                    ),
                  ),
                ),
              );
            },
          ),

          Positioned(
            top: 30,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          Positioned(
            bottom: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.imageUrls.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  height: 8.0,
                  width: _currentPage == index ? 24.0 : 8.0,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Theme.of(context).primaryColor
                        : Colors.white,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class MetricScaleBar extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;

  const MetricScaleBar({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final double percentage = (max > min) ? ((value - min) / (max - min)).clamp(0.0, 1.0) : 0.0;
    final Color barColor = Color.lerp(Colors.blue, Colors.green, percentage) ?? Colors.grey;

    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: Colors.grey[300],
                ),
                child: FractionallySizedBox(
                  widthFactor: percentage,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: barColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}