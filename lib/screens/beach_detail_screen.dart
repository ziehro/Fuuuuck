// lib/screens/beach_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fuuuuck/models/beach_model.dart';
import 'package:fuuuuck/services/beach_data_service.dart';
import 'package:fuuuuck/screens/add_beach_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fuuuuck/services/api/inaturalist_service.dart';
import 'package:fuuuuck/util/metric_ranges.dart';

class BeachDetailScreen extends StatelessWidget {
  final String beachId;

  const BeachDetailScreen({super.key, required this.beachId});

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
          return DefaultTabController(
            length: 2,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 350.0,
                    floating: false,
                    pinned: true,
                    leading: const BackButton(),
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(beach.name, style: const TextStyle(fontSize: 16, color: Colors.white, backgroundColor: Colors.black45)),
                      background: ImageDescriptionCarousel(
                        imageUrls: beach.imageUrls,
                        descriptions: beach.contributedDescriptions,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Card(
                      margin: const EdgeInsets.all(16.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(beach.description, style: Theme.of(context).textTheme.bodyLarge),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_location_alt),
                        label: const Text('Add Your Contribution'),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddBeachScreen(
                              beachId: beach.id,
                              initialLocation: LatLng(beach.latitude, beach.longitude),
                            ),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    delegate: _SliverAppBarDelegate(
                      const TabBar(
                        tabs: [
                          Tab(icon: Icon(Icons.data_usage), text: 'Current Data'),
                          Tab(icon: Icon(Icons.school), text: 'Educational Info'),
                        ],
                      ),
                    ),
                    pinned: true,
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  _buildCurrentDataTab(context, beach),
                  _buildEducationalInfoTab(context, beach),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentDataTab(BuildContext context, Beach beach) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryTitle(context, 'General Metrics'),
          ...beach.aggregatedMetrics.entries.map((entry) {
            final range = metricRanges[entry.key];
            if (range != null) {
              return MetricScaleBar(
                label: entry.key,
                value: entry.value,
                min: range.min.toDouble(),
                max: range.max.toDouble(),
              );
            }
            return _buildDataRow(entry.key, entry.value.toStringAsFixed(2));
          }),
          const SizedBox(height: 16),
          _buildCategoryTitle(context, 'Single-Choice Answers'),
          ...beach.aggregatedSingleChoices.entries.map((entry) {
            final choices = (entry.value).entries.toList()
              ..sort((a, b) => (b.value as int).compareTo(a.value as int));
            final displayText = choices.map((choice) => '${choice.key}: ${choice.value}').join(', ');
            return _buildDataRow(entry.key, displayText);
          }),
          const SizedBox(height: 16),
          _buildCategoryTitle(context, 'Multi-Choice Answers'),
          ...beach.aggregatedMultiChoices.entries.map((entry) {
            final choices = (entry.value).entries.toList()
              ..sort((a, b) => (b.value as int).compareTo(a.value as int));
            final displayText = choices.map((choice) => '${choice.key}: ${choice.value}').join(', ');
            return _buildDataRow(entry.key, displayText);
          }),
          const SizedBox(height: 16),
          _buildCategoryTitle(context, 'AI Identified Flora & Fauna'),
          if (beach.identifiedFloraFauna.isEmpty)
            const Text('No flora or fauna identified yet.')
          else
            ...beach.identifiedFloraFauna.entries.map((entry) {
              return InkWell(
                onLongPress: () => _showFloraFaunaDetailsDialog(context, entry.key, entry.value),
                child: _buildDataRow(entry.key, 'Count: ${entry.value['count']}'),
              );
            }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildEducationalInfoTab(BuildContext context, Beach beach) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryTitle(context, 'Educational Information'),
          Text(beach.educationalInfo.isNotEmpty ? beach.educationalInfo : 'No educational information available yet.', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          _buildCategoryTitle(context, 'Discovery Scavenger Hunt'),
          if (beach.discoveryQuestions.isEmpty)
            Text('No scavenger hunt questions for this beach yet.', style: Theme.of(context).textTheme.bodyMedium)
          else
            ...beach.discoveryQuestions.map((question) => ListTile(leading: const Icon(Icons.explore), title: Text(question))),
        ],
      ),
    );
  }

  Widget _buildCategoryTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }

  Widget _buildDataRow(String key, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(key, style: const TextStyle(fontWeight: FontWeight.bold))),
            Expanded(child: Text(value, textAlign: TextAlign.end)),
          ],
        ),
      ),
    );
  }
}

class ImageDescriptionCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final List<String> descriptions;

  const ImageDescriptionCarousel({
    super.key,
    required this.imageUrls,
    required this.descriptions,
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
    final Color barColor = Color.lerp(Colors.red, Colors.green, percentage) ?? Colors.grey;

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