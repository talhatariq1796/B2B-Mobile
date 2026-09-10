import 'package:b2b_ocr_tool/core/widgets/review_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ReviewField with an icon leaves room for text', (tester) async {
    final controller = TextEditingController(text: 'Jane Doe');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: ReviewField(
              label: 'First name',
              controller: controller,
              icon: Icons.person_outline_rounded,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    // Editable text render box should have real width, not be squeezed to
    // ~0 — regression check for the prefixIcon Align expanding to fill the
    // field instead of shrink-wrapping the icon.
    final editableTextSize = tester.getSize(find.byType(EditableText));
    expect(editableTextSize.width, greaterThan(100));
    expect(find.text('Jane Doe'), findsOneWidget);
  });

  testWidgets('multiline ReviewField with an icon leaves room for text', (tester) async {
    final controller = TextEditingController(text: '123 Main St, Springfield');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: ReviewField(
              label: 'Street address',
              controller: controller,
              icon: Icons.place_outlined,
              maxLines: 2,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final editableTextSize = tester.getSize(find.byType(EditableText));
    expect(editableTextSize.width, greaterThan(100));
    expect(find.text('123 Main St, Springfield'), findsOneWidget);
  });
}
