// Basic widget tests for the example app.
//
// These tests only verify static UI structure; they deliberately avoid
// tapping the save buttons, which invoke platform channels that are not
// available in widget tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:public_file_saver_example/main.dart';

void main() {
  testWidgets('renders demo UI with all save modes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    // App bar and initial status
    expect(find.text('Public File Saver Demo'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);

    // All four save modes are present
    expect(find.text('Mode A: saveBytes (No Dialog)'), findsOneWidget);
    expect(find.text('Mode B: saveBytesWithDialog'), findsOneWidget);
    expect(find.text('Mode C: saveFile (with subDir)'), findsOneWidget);
    expect(find.text('Mode D: saveFromUrl'), findsOneWidget);

    // Buttons
    expect(
      find.ancestor(
          of: find.text('Save Text File'),
          matching:
              find.byWidgetPredicate((widget) => widget is ElevatedButton)),
      findsOneWidget,
    );
    expect(
      find.ancestor(
          of: find.text('Save JSON with Dialog'),
          matching:
              find.byWidgetPredicate((widget) => widget is ElevatedButton)),
      findsOneWidget,
    );
    expect(
      find.ancestor(
          of: find.text('Save to Subdirectory'),
          matching:
              find.byWidgetPredicate((widget) => widget is ElevatedButton)),
      findsOneWidget,
    );
    expect(
        find.ancestor(
            of: find.text('Download'),
            matching:
                find.byWidgetPredicate((widget) => widget is ElevatedButton)),
        findsOneWidget);
    expect(
        find.ancestor(
            of: find.text('With Dialog'),
            matching:
                find.byWidgetPredicate((widget) => widget is ElevatedButton)),
        findsOneWidget);

    // URL input
    expect(find.byType(TextField), findsOneWidget);

    // Result card is hidden until a save succeeds
    expect(find.text('Last Result'), findsNothing);
  });
}
