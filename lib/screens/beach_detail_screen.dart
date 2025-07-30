// lib/screens/beach_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fuuuuck/models/beach_model.dart';
import 'package:fuuuuck/services/beach_data_service.dart';
import 'package:fuuuuck/screens/add_beach_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fuuuuck/services/api/inaturalist_service.dart';
import 'package:fuuuuck/util/metric_ranges.dart';
import 'package:fuuuuck/services/gemini_service.dart';
import 'package:fuuuuck/util/long_press_descriptions.dart';

class BeachDetailScreen extends StatelessWidget {
  final String beachId;

  const BeachDetailScreen({super.key, required this.beachId});

  // --- Metric Category Keys ---
  static const List<String> floraMetricKeys = [
    'Kelp Beach', 'Seaweed Beach', 'Seaweed Rocks'
  ];
  // Reordered from biggest to smallest
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
    // Get the description from our new map, or use a default if not found.
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
                      child: Text(
                        beach.name,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricsCategoryTab(context, beach, floraMetricKeys),
          const SizedBox(height: 16),
          _buildCategoryTitle(context, 'Answers'),
          if (beach.aggregatedTextItems.containsKey('Tree types'))
            _buildDataRow(
              context,
              'Tree types',
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: (beach.aggregatedTextItems['Tree types'] as List<dynamic>).map((e) => Text(e.toString(), textAlign: TextAlign.end)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFaunaTab(BuildContext context, Beach beach) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricsCategoryTab(context, beach, faunaMetricKeys),
          const SizedBox(height: 16),
          _buildCategoryTitle(context, 'Answers'),
          if (beach.aggregatedTextItems.containsKey('Birds'))
            _buildDataRow(
              context,
              'Birds',
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: (beach.aggregatedTextItems['Birds'] as List<dynamic>).map((e) => Text(e.toString(), textAlign: TextAlign.end)).toList(),
              ),
            ),
          if (beach.aggregatedMultiChoices.containsKey('Which Shells'))
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: _buildMetricsCategoryTab(context, beach, woodMetricKeys),
    );
  }

  Widget _buildCompositionTab(BuildContext context, Beach beach) {
    // Keys that will be handled by the generic metrics tab logic, excluding Width and Length
    final List<String> remainingCompositionKeys = List.from(compositionOrderedKeys)
      ..remove('Width')
      ..remove('Length');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Explicitly handle Width and Length at the top for visibility
          if (beach.aggregatedMetrics.containsKey('Width'))
            _buildDataRow(context, 'Width', Text('${beach.aggregatedMetrics['Width']!.toStringAsFixed(0)} steps', textAlign: TextAlign.end)),
          if (beach.aggregatedMetrics.containsKey('Length'))
            _buildDataRow(context, 'Length', Text('${beach.aggregatedMetrics['Length']!.toStringAsFixed(0)} steps', textAlign: TextAlign.end)),

          // Handle the rest of the metrics using the generic builder
          _buildMetricsCategoryTab(context, beach, remainingCompositionKeys, isComposition: true),

          const SizedBox(height: 16),
          _buildCategoryTitle(context, 'Answers'),
          if (beach.aggregatedSingleChoices.containsKey('Shape'))
            _buildDataRow(
              context,
              'Shape',
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: (beach.aggregatedSingleChoices['Shape'] as Map<String, dynamic>).entries.map((e) => Text('${e.key}: ${e.value}')).toList(),
              ),
            ),
          if (beach.aggregatedMultiChoices.containsKey('Bluff Comp'))
            _buildDataRow(
              context,
              'Bluff Comp',
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: (beach.aggregatedMultiChoices['Bluff Comp'] as Map<String, dynamic>).entries.map((e) => Text('${e.key}: ${e.value}')).toList(),
              ),
            ),
          if (beach.aggregatedSingleChoices.containsKey('Rock Type'))
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
          filteredMetrics[key] = value;
        }
      });
    } else if (isComposition) {
      for (var key in keys) {
        if (beach.aggregatedMetrics.containsKey(key)) {
          filteredMetrics[key] = beach.aggregatedMetrics[key]!;
        }
      }
    } else {
      beach.aggregatedMetrics.forEach((key, value) {
        if (keys.contains(key)) {
          filteredMetrics[key] = value;
        }
      });
    }

    if (filteredMetrics.isEmpty) {
      // Return an empty container if there are no other metrics to display.
      // The main tab builder will handle showing a message if the whole tab is empty.
      return const SizedBox.shrink();
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
        // This handles metrics that don't use a slider, like Bluff Height
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

  @override
  Widget build(BuildContext context) {
    final displayDescriptions = widget.descriptions.isNotEmpty ? widget.descriptions : ['No description available.'];

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
              return Image.network(
                widget.imageUrls[index],
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) =>
                const Center(child: Icon(Icons.broken_image, size: 100, color: Colors.grey)),
              );
            },
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Chip(
              avatar: const Icon(Icons.people, color: Colors.white),
              label: Text(
                '${widget.contributionCount} Contributions',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.black.withOpacity(0.6),
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.black.withOpacity(0.6),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            child: Text(
              widget.descriptions.length > _currentPage ? widget.descriptions[_currentPage] : displayDescriptions[0],
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
                    color: _currentPage == index ? Theme.of(context).primaryColor : Colors.white,
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
                Text(value.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
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