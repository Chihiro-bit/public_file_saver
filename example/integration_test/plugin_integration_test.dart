// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:public_file_saver/public_file_saver.dart';


void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('saveBytes saves a small text file', (WidgetTester tester) async {
    final fileSaver = PublicFileSaver();

    final bytes = utf8.encode('public_file_saver integration test');

    final result = await fileSaver.saveBytes(
      bytes: bytes,
      fileName: 'integration_test_${DateTime.now().millisecondsSinceEpoch}.txt',
      mimeType: 'text/plain',
    );

    expect(result, isNotNull);
    expect(result!.isSuccess, isTrue);
    expect(result.fileName, endsWith('.txt'));
  });
}
