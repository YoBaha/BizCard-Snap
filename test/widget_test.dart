import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bizcard_snap/main.dart';

void main() {
  testWidgets('BizCardSnap launches with HomePage', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(const BizCardSnapApp());

    // Verify that the app bar title is present.
    expect(find.text('BizCardSnap'), findsOneWidget);

    // Verify the initial state (e.g., the upload button is visible).
    expect(find.widgetWithText(ElevatedButton, 'Scan Business Card'), findsOneWidget);

    // Optionally, you can add more checks (e.g., no error message initially).
    expect(find.text('error'), findsNothing);
  });
}