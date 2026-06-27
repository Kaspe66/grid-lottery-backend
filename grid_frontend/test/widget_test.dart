import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grid_frontend/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GridLotteryApp());

    // Verify that the coin icon is present.
    expect(find.byIcon(Icons.monetization_on), findsOneWidget);
  });
}
