// lib/screens/migration_screen.dart
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:mybeachbook/services/migration_service.dart';

class MigrationScreen extends StatefulWidget {
  const MigrationScreen({super.key});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  final MigrationService _migrationService = MigrationService();
  final ScrollController _scrollController = ScrollController();

  // Run state
  bool _isRunning = false;
  bool _isPaused = false;

  // Output panel
  String _output = '';

  // AI Generation options
  bool _generateAiDescriptions = true;
  bool _generateAiImages = false;
  int _aiImageFrequency = 3;
  bool _skipExisting = true;

  // Run limit
  final TextEditingController _maxController = TextEditingController(text: '0');
  int get _maxBeachesThisRun {
    final parsed = int.tryParse(_maxController.text.trim());
    return (parsed == null || parsed < 0) ? 0 : parsed;
  }
  int _processedThisRun = 0;

  // Migration statistics
  Map<String, int> _migrationStats = {};
  bool _statsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMigrationStats();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _scrollController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  // ---------- Stats ----------

  Future<void> _loadMigrationStats() async {
    setState(() => _statsLoading = true);
    try {
      final stats = await _migrationService.getMigrationStats();
      setState(() => _migrationStats = stats);
    } catch (e) {
      _addOutput('⚠️ Error loading stats: $e');
    } finally {
      setState(() => _statsLoading = false);
    }
  }

  Widget _buildStatsCard() {
    if (_statsLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Migration Statistics',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadMigrationStats,
                  tooltip: 'Refresh Statistics',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_migrationStats.isNotEmpty) ...[
              _buildStatRow('Total Old Beaches', _migrationStats['totalOldBeaches'] ?? 0),
              _buildStatRow('Already Processed', _migrationStats['processedCount'] ?? 0,
                  color: Colors.green),
              _buildStatRow('Remaining', _migrationStats['remainingCount'] ?? 0,
                  color: Colors.orange),
              _buildStatRow('New Beaches Created', _migrationStats['totalNewBeaches'] ?? 0,
                  color: Colors.blue),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_migrationStats['totalOldBeaches'] ?? 0) > 0
                    ? (_migrationStats['processedCount'] ?? 0) /
                    ((_migrationStats['totalOldBeaches'] ?? 1).toDouble())
                    : 0,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ] else
              const Text('No statistics available', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value.toString(),
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  // ---------- Helpers ----------

  void _addOutput(String text) {
    setState(() {
      _output += '$text\n';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Enforce per-run limit based on a **single, unambiguous marker** from the service.
  /// Emit this once per migrated beach from MigrationService:
  ///   onProgress('[BEACH_DONE] <id or name>')
  void _onProgressWithLimit(String text) {
    _addOutput(text);

    final limit = _maxBeachesThisRun;
    if (limit <= 0) return; // unlimited

    // Strict match: only count when the explicit token appears.
    // (Avoids lifetime counters like "Processed 432 total" tripping the limit.)
    final done = RegExp(r'(\[BEACH_DONE\]|\bBEACH_DONE\b|::BEACH_DONE::)').hasMatch(text);
    if (!done) return;

    _processedThisRun++;
    if (_processedThisRun >= limit) {
      _addOutput('⛔ Max beaches for this run reached ($limit). Stopping…');
      _stopMigration(); // gracefully requests stop + releases wakelock
    }
  }

  void _clearOutput() {
    setState(() => _output = '');
  }

  void _pauseResumeMigration() {
    if (_isPaused) {
      _migrationService.resumeMigration();
      _addOutput('▶️ Migration resumed');
    } else {
      _migrationService.pauseMigration();
      _addOutput('⏸️ Migration paused');
    }
    setState(() => _isPaused = !_isPaused);
  }

  void _stopMigration() {
    _migrationService.stopMigration();
    _addOutput('🛑 Migration stop requested...');
    setState(() {
      _isRunning = false;
      _isPaused = false;
    });
    WakelockPlus.disable();
    _addOutput('🔓 Screen wake lock released');
  }

  String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) return 'th';
    switch (number % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  // ---------- Actions ----------

  Future<void> _clearTrackingData() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Tracking Data'),
        content: const Text(
          'This will clear all migration tracking data, allowing beaches to be migrated again. '
              'This is useful if you want to start fresh or if there were errors.\n\n'
              'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isRunning = true);
      await _migrationService.clearMigrationTracking(onProgress: _addOutput);
      await _loadMigrationStats();
      setState(() => _isRunning = false);
    }
  }

  Future<void> _runTestMigration() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _processedThisRun = 0; // reset per-run counter
    });
    await WakelockPlus.enable();
    _addOutput('🔒 Screen will stay awake during migration');
    _addOutput('🧪 Starting test migration...');

    try {
      await _migrationService.testMigration(onProgress: _onProgressWithLimit);
      _addOutput('✅ Test migration completed!');
    } catch (e) {
      _addOutput('❌ Test migration failed: $e');
    } finally {
      setState(() => _isRunning = false);
      await WakelockPlus.disable();
      _addOutput('🔓 Screen wake lock released');
    }
  }

  Future<void> _runTestMigrationWithWrite() async {
    if (_isRunning) return;

    final result = await showDialog<Map<String, bool>>(
      context: context,
      builder: (context) {
        bool testAiDescription = true;
        bool testAiImage = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Test & Write Options'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Choose what to test:'),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Generate AI Description'),
                  subtitle: const Text('~2-3 seconds, ~\$0.002'),
                  value: testAiDescription,
                  onChanged: (v) => setDialogState(() => testAiDescription = v ?? true),
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Generate AI Image'),
                  subtitle: const Text('~10-15 seconds, ~\$0.040'),
                  value: testAiImage,
                  onChanged: (v) => setDialogState(() => testAiImage = v ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, {
                  'description': testAiDescription,
                  'image': testAiImage,
                }),
                child: const Text('Test'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;

    setState(() {
      _isRunning = true;
      _processedThisRun = 0; // reset per-run counter
    });
    await WakelockPlus.enable();
    _addOutput('🔒 Screen will stay awake during migration');

    final aiDesc = result['description'] ?? true;
    final aiImg = result['image'] ?? false;
    _addOutput(
        '🧪 Starting test with AI Description: ${aiDesc ? "✅" : "❌"}, AI Image: ${aiImg ? "✅" : "❌"}');

    try {
      await _migrationService.testMigrationWithWrite(
        onProgress: _onProgressWithLimit,
        generateAiDescription: aiDesc,
        generateAiImage: aiImg,
        skipExisting: true,
      );
      _addOutput('✅ Test migration with write completed!');
      await _loadMigrationStats();
    } catch (e) {
      _addOutput('❌ Test migration with write failed: $e');
    } finally {
      setState(() => _isRunning = false);
      await WakelockPlus.disable();
      _addOutput('🔓 Screen wake lock released');
    }
  }

  Future<void> _testSpecificDoc() async {
    if (_isRunning) return;

    final TextEditingController controller = TextEditingController();
    final String? docId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test Specific Document'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Document ID',
            hintText: 'Enter the document ID to test',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Test'),
          ),
        ],
      ),
    );

    if (docId == null || docId.isEmpty) return;

    setState(() {
      _isRunning = true;
      _processedThisRun = 0; // reset per-run counter
    });
    await WakelockPlus.enable();
    _addOutput('🔒 Screen will stay awake during migration');
    _addOutput('🔍 Testing migration for document: $docId');

    try {
      await _migrationService.testMigration(
        specificDocId: docId,
        onProgress: _onProgressWithLimit,
      );
      _addOutput('✅ Test completed for document: $docId');
    } catch (e) {
      _addOutput('❌ Test failed for document $docId: $e');
    } finally {
      setState(() => _isRunning = false);
      await WakelockPlus.disable();
      _addOutput('🔓 Screen wake lock released');
    }
  }

  Future<void> _runFullMigration() async {
    if (_isRunning) return;

    final totalBeaches = _migrationStats['totalOldBeaches'] ?? 0;
    final remaining = _migrationStats['remainingCount'] ?? totalBeaches;

    final limit = _maxBeachesThisRun;
    final plannedThisRun = limit > 0 ? (remaining < limit ? remaining : limit) : remaining;

    final imageCount =
    _generateAiImages ? (plannedThisRun / _aiImageFrequency).ceil() : 0;
    final estimatedCost = (plannedThisRun * 0.002) + (imageCount * 0.040);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Migration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will migrate remaining data from the old collection to beaches.'),
            const SizedBox(height: 12),
            Text('📊 Total beaches: $totalBeaches'),
            Text('✅ Already processed: ${_migrationStats['processedCount'] ?? 0}'),
            Text('🔄 Remaining: $remaining'),
            Text('🎯 This run will process: $plannedThisRun'
                '${limit > 0 ? " (limited to $limit)" : ""}'),
            Text('🤖 AI Descriptions: ${_generateAiDescriptions ? "Yes" : "No"}'),
            Text(
              '🎨 AI Images: ${_generateAiImages ? "Yes (every ${_aiImageFrequency}${_getOrdinalSuffix(_aiImageFrequency)} beach = $imageCount images)" : "No"}',
            ),
            const SizedBox(height: 8),
            Text(
              '💰 Estimated cost this run: \$${estimatedCost.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'This action will only process beaches not already migrated.',
              style: TextStyle(color: Colors.green),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Migrate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isRunning = true;
      _isPaused = false;
      _processedThisRun = 0; // reset per-run counter
    });

    await WakelockPlus.enable();
    _addOutput('🔒 Screen will stay awake during migration');
    _addOutput('🚀 Starting migration with UUID tracking...'
        '${limit > 0 ? " (limit $limit)" : ""}');

    try {
      await _migrationService.migrateAllData(
        onProgress: _addOutput,
        generateAiDescriptions: _generateAiDescriptions,
        generateAiImages: _generateAiImages,
        aiImageFrequency: _aiImageFrequency,
        skipExisting: _skipExisting,
        maxItems: _maxBeachesThisRun, // <-- pass the per-run cap here
      );


      if (_processedThisRun < plannedThisRun) {
        _addOutput('🎉 Migration completed!');
      } else {
        _addOutput('✅ Reached run limit of $plannedThisRun beaches.');
      }
      await _loadMigrationStats();
    } catch (e) {
      _addOutput('💥 Migration failed: $e');
    } finally {
      setState(() {
        _isRunning = false;
        _isPaused = false;
      });
      await WakelockPlus.disable();
      _addOutput('🔓 Screen wake lock released');
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Migration'),
        actions: [
          IconButton(
            onPressed: _clearOutput,
            icon: const Icon(Icons.clear),
            tooltip: 'Clear Output',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top: scrollable content section
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatsCard(),
                    const SizedBox(height: 16),

                    const Text(
                      'BeachBook Data Migration',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This tool migrates data with UUID tracking to prevent duplicates.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // Run limit control
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.filter_alt),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Max beaches this run',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: _maxController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: '0 = All',
                                  labelText: 'Count',
                                ),
                                onChanged: (_) => setState(() {}), // refresh estimates
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // AI Generation Options
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('AI Generation Options',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),

                            CheckboxListTile(
                              title: const Text('Generate AI Descriptions'),
                              subtitle: const Text('~\$0.002 per beach'),
                              value: _generateAiDescriptions,
                              onChanged: (value) =>
                                  setState(() => _generateAiDescriptions = value ?? true),
                              contentPadding: EdgeInsets.zero,
                            ),

                            CheckboxListTile(
                              title: const Text('Generate AI Images'),
                              subtitle: Text(
                                  '~\$0.040 per image (every ${_aiImageFrequency}${_getOrdinalSuffix(_aiImageFrequency)} beach)'),
                              value: _generateAiImages,
                              onChanged: (value) =>
                                  setState(() => _generateAiImages = value ?? false),
                              contentPadding: EdgeInsets.zero,
                            ),

                            CheckboxListTile(
                              title: const Text('Skip Existing Beaches'),
                              subtitle:
                              const Text('Use UUID tracking to avoid duplicates'),
                              value: _skipExisting,
                              onChanged: (value) =>
                                  setState(() => _skipExisting = value ?? true),
                              contentPadding: EdgeInsets.zero,
                            ),

                            if (_generateAiImages)
                              Padding(
                                padding: const EdgeInsets.only(left: 16.0),
                                child: Row(
                                  children: [
                                    const Text('Image frequency: Every '),
                                    DropdownButton<int>(
                                      value: _aiImageFrequency,
                                      items: [1, 2, 3, 4, 5]
                                          .map(
                                            (i) => DropdownMenuItem(
                                          value: i,
                                          child: Text('$i${_getOrdinalSuffix(i)}'),
                                        ),
                                      )
                                          .toList(),
                                      onChanged: (value) => setState(
                                              () => _aiImageFrequency = value ?? 3),
                                    ),
                                    const Text(' beach'),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Test Controls
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isRunning ? null : _runTestMigration,
                            icon: _isRunning
                                ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                                : const Icon(Icons.science),
                            label: const Text('Test Only'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isRunning ? null : _runTestMigrationWithWrite,
                            icon: const Icon(Icons.create),
                            label: const Text('Test & Write'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isRunning ? null : _testSpecificDoc,
                            icon: const Icon(Icons.search),
                            label: const Text('Test Specific'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Main Migration Controls
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isRunning ? null : _runFullMigration,
                            icon: _isRunning
                                ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                                : const Icon(Icons.rocket_launch),
                            label: const Text('Run Migration'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isRunning ? null : _clearTrackingData,
                            icon: const Icon(Icons.delete_sweep),
                            label: const Text('Clear Tracking'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_isRunning) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _pauseResumeMigration,
                              icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                              label: Text(_isPaused ? 'Resume' : 'Pause'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _stopMigration,
                              icon: const Icon(Icons.stop),
                              label: const Text('Stop'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // Separator line
            Container(height: 1, color: Colors.grey[300]),

            // Bottom: Output panel (fixed height via Expanded)
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Output',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (_output.isNotEmpty)
                          TextButton.icon(
                            onPressed: _clearOutput,
                            icon: const Icon(Icons.clear, size: 16),
                            label: const Text('Clear'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _output.isEmpty
                            ? const Center(
                          child: Text(
                            'Output will appear here...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                            : SingleChildScrollView(
                          controller: _scrollController,
                          child: Text(
                            _output,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
