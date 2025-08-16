// lib/screens/migration_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import
import 'package:fuuuuck/services/migration_service.dart';

class MigrationScreen extends StatefulWidget {
  const MigrationScreen({super.key});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  final MigrationService _migrationService = MigrationService();
  bool _isRunning = false;
  bool _isPaused = false;
  String _output = '';
  final ScrollController _scrollController = ScrollController();

  // AI Generation options
  bool _generateAiDescriptions = true;
  bool _generateAiImages = false;
  int _aiImageFrequency = 3;
  bool _skipExisting = true;

  void _addOutput(String text) {
    setState(() {
      _output += '$text\n';
    });
    // Auto-scroll to bottom
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

  void _clearOutput() {
    setState(() {
      _output = '';
    });
  }

  void _pauseResumeMigration() {
    if (_isPaused) {
      _migrationService.resumeMigration();
      _addOutput('▶️ Migration resumed');
    } else {
      _migrationService.pauseMigration();
      _addOutput('⏸️ Migration paused');
    }
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _stopMigration() {
    _migrationService.stopMigration();
    _addOutput('🛑 Migration stop requested...');
    setState(() {
      _isRunning = false;
      _isPaused = false;
    });
  }

  Future<void> _runTestMigrationWithWrite() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
    });

    _addOutput('🧪 Starting test migration with write...');

    try {
      await _migrationService.testMigrationWithWrite(onProgress: _addOutput);
      _addOutput('✅ Test migration with write completed!');
    } catch (e) {
      _addOutput('❌ Test migration with write failed: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _runTestMigration() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
    });

    _addOutput('🧪 Starting test migration...');

    try {
      await _migrationService.testMigration(onProgress: _addOutput);

      _addOutput('✅ Test migration completed!');
    } catch (e) {
      _addOutput('❌ Test migration failed: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _runFullMigration() async {
    if (_isRunning) return;

    // Calculate estimated cost
    final QuerySnapshot oldBeaches = await FirebaseFirestore.instance
        .collection('locations')
        .get();
    final beachCount = oldBeaches.docs.length;
    final imageCount = _generateAiImages ? (beachCount / _aiImageFrequency).ceil() : 0;
    final estimatedCost = (beachCount * 0.002) + (imageCount * 0.040);

    // Show confirmation dialog with cost estimate
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Migration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will migrate ALL data from the old collection to beaches.'),
            const SizedBox(height: 12),
            Text('📊 Beaches to migrate: $beachCount'),
            Text('🤖 AI Descriptions: ${_generateAiDescriptions ? "Yes" : "No"}'),
            Text('🎨 AI Images: ${_generateAiImages ? "Yes (every ${_aiImageFrequency}rd beach = $imageCount images)" : "No"}'),
            const SizedBox(height: 8),
            Text('💰 Estimated cost: \${estimatedCost.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('This action cannot be undone. Are you sure?',
                style: TextStyle(color: Colors.red)),
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
    });

    _addOutput('🚀 Starting full migration with AI generation...');

    try {
      await _migrationService.migrateAllData(
        onProgress: _addOutput,
        generateAiDescriptions: _generateAiDescriptions,
        generateAiImages: _generateAiImages,
        aiImageFrequency: _aiImageFrequency,
        skipExisting: _skipExisting,
      );

      _addOutput('🎉 Full migration completed!');
    } catch (e) {
      _addOutput('💥 Migration failed: $e');
    } finally {
      setState(() {
        _isRunning = false;
        _isPaused = false;
      });
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
    });

    _addOutput('🔍 Testing migration for document: $docId');

    try {
      await _migrationService.testMigration(
        specificDocId: docId,
        onProgress: _addOutput,
      );

      _addOutput('✅ Test completed for document: $docId');
    } catch (e) {
      _addOutput('❌ Test failed for document $docId: $e');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

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
      body: Column(
        children: [
          // Control Panel
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'BeachBook Data Migration',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This tool will migrate data from your old Android app to the new Flutter app format.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // AI Generation Options
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('AI Generation Options', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),

                        CheckboxListTile(
                          title: const Text('Generate AI Descriptions'),
                          subtitle: const Text('~\$0.002 per beach'),
                          value: _generateAiDescriptions,
                          onChanged: (value) => setState(() => _generateAiDescriptions = value ?? true),
                          contentPadding: EdgeInsets.zero,
                        ),

                        CheckboxListTile(
                          title: const Text('Generate AI Images'),
                          subtitle: Text('~\$0.040 per image (every ${_aiImageFrequency}rd beach)'),
                          value: _generateAiImages,
                          onChanged: (value) => setState(() => _generateAiImages = value ?? false),
                          contentPadding: EdgeInsets.zero,
                        ),

                        CheckboxListTile(
                          title: const Text('Skip Existing Beaches'),
                          subtitle: const Text('Avoid duplicates on multiple passes'),
                          value: _skipExisting,
                          onChanged: (value) => setState(() => _skipExisting = value ?? true),
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
                                  items: [1, 2, 3, 4, 5].map((i) => DropdownMenuItem(
                                    value: i,
                                    child: Text('${i}rd'),
                                  )).toList(),
                                  onChanged: (value) => setState(() => _aiImageFrequency = value ?? 3),
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
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isRunning ? null : _runFullMigration,
                  icon: _isRunning
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.rocket_launch),
                  label: const Text('Run Full Migration'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),

                // Pause/Stop controls (only show when migration is running)
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
              ],
            ),
          ),

          const Divider(),

          // Output Panel
          Expanded(
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
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}