import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:b2b_ocr_tool/app/app.dart';
import 'package:b2b_ocr_tool/core/di/injection_container.dart';

void main() {
  setUpAll(() async {
    await initDependencies();
  });

  Future<void> pumpAtPhoneSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const App(restoredSession: false));
    await tester.pumpAndSettle();
  }

  testWidgets('App boots and shows the login screen', (WidgetTester tester) async {
    await pumpAtPhoneSize(tester);

    expect(find.text('Agency check-in'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('Guest CTA reaches the capture screen', (WidgetTester tester) async {
    await pumpAtPhoneSize(tester);

    await tester.tap(find.text('Continue as guest'));
    // Capture has a repeating scan-line animation, so pumpAndSettle would
    // never resolve — pump a fixed number of frames instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Scan a card'), findsOneWidget);
  });
}
