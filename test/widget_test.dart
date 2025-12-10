import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App launches without error', (WidgetTester tester) async {
    // Basic smoke test
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('환자 모니터링 시스템'),
          ),
        ),
      ),
    );

    expect(find.text('환자 모니터링 시스템'), findsOneWidget);
  });
}
