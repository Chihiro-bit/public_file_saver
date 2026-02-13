import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:public_file_saver/public_file_saver.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Public File Saver Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const FileSaverDemo(),
    );
  }
}

class FileSaverDemo extends StatefulWidget {
  const FileSaverDemo({super.key});

  @override
  State<FileSaverDemo> createState() => _FileSaverDemoState();
}

class _FileSaverDemoState extends State<FileSaverDemo> {
  final _fileSaver = PublicFileSaver();
  final _urlController = TextEditingController(
    text: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
  );

  String _status = 'Ready';
  PublicSavedFile? _lastResult;
  bool _isLoading = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  /// Generate sample text file bytes
  Uint8List _generateTextBytes() {
    final content = '''
Hello from Public File Saver!

This is a sample text file created at:
${DateTime.now().toIso8601String()}

Platform: Flutter
Plugin: public_file_saver

This file demonstrates the saveBytes functionality.
''';
    return Uint8List.fromList(utf8.encode(content));
  }

  /// Generate sample JSON bytes
  Uint8List _generateJsonBytes() {
    final data = {
      'name': 'Public File Saver Demo',
      'timestamp': DateTime.now().toIso8601String(),
      'version': '1.0.0',
      'features': ['saveBytes', 'saveBytesWithDialog', 'saveFile', 'saveFromUrl'],
      'platforms': ['Android', 'iOS', 'HarmonyOS'],
    };
    return Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(data)));
  }

  void _setLoading(bool loading) {
    setState(() {
      _isLoading = loading;
    });
  }

  void _updateStatus(String status, [PublicSavedFile? result]) {
    setState(() {
      _status = status;
      _lastResult = result;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Test Mode A: saveBytes (no dialog)
  Future<void> _testSaveBytes() async {
    _setLoading(true);
    _updateStatus('Saving bytes...');

    try {
      final bytes = _generateTextBytes();
      final result = await _fileSaver.saveBytes(
        bytes: bytes,
        fileName: 'test_file_${DateTime.now().millisecondsSinceEpoch}.txt',
        mimeType: 'text/plain',
      );

      if (result != null && result.isSuccess) {
        _updateStatus('✅ saveBytes succeeded!', result);
        _showSnackBar('File saved successfully!');
      } else {
        _updateStatus('❌ saveBytes returned null (cancelled or failed)');
        _showSnackBar('Save cancelled or failed', isError: true);
      }
    } catch (e) {
      _updateStatus('❌ Error: $e');
      _showSnackBar('Error: $e', isError: true);
    } finally {
      _setLoading(false);
    }
  }

  /// Test Mode B: saveBytesWithDialog
  Future<void> _testSaveBytesWithDialog() async {
    _setLoading(true);
    _updateStatus('Opening save dialog...');

    try {
      final bytes = _generateJsonBytes();
      final result = await _fileSaver.saveBytesWithDialog(
        bytes: bytes,
        fileName: 'demo_data.json',
        mimeType: 'application/json',
      );

      if (result != null && result.isSuccess) {
        _updateStatus('✅ saveBytesWithDialog succeeded!', result);
        _showSnackBar('File saved successfully!');
      } else {
        _updateStatus('❌ User cancelled or save failed');
        _showSnackBar('Save cancelled', isError: true);
      }
    } catch (e) {
      _updateStatus('❌ Error: $e');
      _showSnackBar('Error: $e', isError: true);
    } finally {
      _setLoading(false);
    }
  }

  /// Test Mode C: saveFile (using generated temp content as demo)
  Future<void> _testSaveFile() async {
    _setLoading(true);
    _updateStatus('Creating temp file and saving...');

    try {
      // For demo purposes, we'll use saveBytes since we don't have a real file
      // In real usage, you would pass an actual File object
      final bytes = _generateTextBytes();
      final result = await _fileSaver.saveBytes(
        bytes: bytes,
        fileName: 'saved_local_file.txt',
        mimeType: 'text/plain',
        subDir: 'PublicFileSaverDemo', // Test subdirectory (Android only)
      );

      if (result != null && result.isSuccess) {
        _updateStatus('✅ saveFile (via saveBytes) succeeded!', result);
        _showSnackBar('File saved to subdirectory!');
      } else {
        _updateStatus('❌ saveFile returned null');
        _showSnackBar('Save failed', isError: true);
      }
    } catch (e) {
      _updateStatus('❌ Error: $e');
      _showSnackBar('Error: $e', isError: true);
    } finally {
      _setLoading(false);
    }
  }

  /// Test Mode D: saveFromUrl
  Future<void> _testSaveFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnackBar('Please enter a URL', isError: true);
      return;
    }

    _setLoading(true);
    _updateStatus('Downloading from URL...');

    try {
      final result = await _fileSaver.saveFromUrl(
        url: url,
        useDialog: false, // Set to true to show dialog
      );

      if (result != null && result.isSuccess) {
        _updateStatus('✅ saveFromUrl succeeded!', result);
        _showSnackBar('File downloaded and saved!');
      } else {
        _updateStatus('❌ saveFromUrl returned null');
        _showSnackBar('Download/save failed', isError: true);
      }
    } catch (e) {
      _updateStatus('❌ Error: $e');
      _showSnackBar('Error: $e', isError: true);
    } finally {
      _setLoading(false);
    }
  }

  /// Test saveFromUrl with dialog
  Future<void> _testSaveFromUrlWithDialog() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnackBar('Please enter a URL', isError: true);
      return;
    }

    _setLoading(true);
    _updateStatus('Downloading from URL...');

    try {
      final result = await _fileSaver.saveFromUrl(
        url: url,
        useDialog: true,
      );

      if (result != null && result.isSuccess) {
        _updateStatus('✅ saveFromUrl with dialog succeeded!', result);
        _showSnackBar('File downloaded and saved!');
      } else {
        _updateStatus('❌ User cancelled or failed');
        _showSnackBar('Cancelled or failed', isError: true);
      }
    } catch (e) {
      _updateStatus('❌ Error: $e');
      _showSnackBar('Error: $e', isError: true);
    } finally {
      _setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Public File Saver Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline),
                        const SizedBox(width: 8),
                        const Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isLoading) ...[
                          const SizedBox(width: 16),
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_status),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Result Card
            if (_lastResult != null)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'Last Result',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildResultRow('fileName', _lastResult!.fileName),
                      _buildResultRow('uri', _lastResult!.uri ?? 'null'),
                      _buildResultRow('path', _lastResult!.path ?? 'null'),
                      _buildResultRow('isSuccess', _lastResult!.isSuccess.toString()),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Mode A: saveBytes
            const Text(
              'Mode A: saveBytes (No Dialog)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testSaveBytes,
              icon: const Icon(Icons.save),
              label: const Text('Save Text File'),
            ),

            const SizedBox(height: 24),

            // Mode B: saveBytesWithDialog
            const Text(
              'Mode B: saveBytesWithDialog',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testSaveBytesWithDialog,
              icon: const Icon(Icons.save_as),
              label: const Text('Save JSON with Dialog'),
            ),

            const SizedBox(height: 24),

            // Mode C: saveFile
            const Text(
              'Mode C: saveFile (with subDir)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testSaveFile,
              icon: const Icon(Icons.folder),
              label: const Text('Save to Subdirectory'),
            ),

            const SizedBox(height: 24),

            // Mode D: saveFromUrl
            const Text(
              'Mode D: saveFromUrl',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'Enter file URL to download',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _testSaveFromUrl,
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _testSaveFromUrlWithDialog,
                    icon: const Icon(Icons.download_for_offline),
                    label: const Text('With Dialog'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Info section
            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.help_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Platform Notes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Android 10+: Returns content:// URI\n'
                      '• Android 9-: Returns file path\n'
                      '• iOS: Returns path in Documents (visible in Files app)\n'
                      '• OHOS: Returns URI and path\n'
                      '• Dialog cancel returns null',
                      style: TextStyle(fontSize: 13),
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

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

