import 'dart:convert';
import 'dart:io';

import 'package:b2b_ocr_tool/core/widgets/image_preview_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Minimal valid 4x4 PNG, embedded so this test needs no fixture file.
const _tinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAE0lEQVR4nGM8EaDBAANMcBZe'
    'DgBAJAFIufyWTwAAAABJRU5ErkJggg==';

void main() {
  testWidgets('tapping an image opens a full-screen preview with a close button', (
    tester,
  ) async {
    final file = File('${Directory.systemTemp.path}/image_preview_viewer_test.png');
    await file.writeAsBytes(base64Decode(_tinyPngBase64));
    addTearDown(() => file.delete());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () => openImagePreview(context, localPath: file.path),
              child: const Text('card thumbnail'),
            ),
          ),
        ),
      ),
    );

    // Not shown until tapped.
    expect(find.byType(InteractiveViewer), findsNothing);

    await tester.tap(find.text('card thumbnail'));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Closed — back to the underlying screen, preview gone.
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.text('card thumbnail'), findsOneWidget);
  });

  testWidgets('does nothing when there is no image to show', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => GestureDetector(
              onTap: () => openImagePreview(context),
              child: const Text('empty'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('empty'));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsNothing);
  });
}
