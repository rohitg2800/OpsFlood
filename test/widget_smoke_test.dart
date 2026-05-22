// test/widget_smoke_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:equinox_flood/widgets/error_card.dart';

void main() {
  group('ErrorCard smoke tests', () {
    testWidgets('renders message text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorCard(message: 'Live data unavailable'),
          ),
        ),
      );
      expect(find.text('Live data unavailable'), findsOneWidget);
    });

    testWidgets('shows Retry button when onRetry provided', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorCard(
              message: 'Connection failed',
              onRetry: () => tapped = true,
            ),
          ),
        ),
      );
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(tapped, isTrue);
    });

    testWidgets('hides Retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorCard(message: 'No connection'),
          ),
        ),
      );
      expect(find.text('Retry'), findsNothing);
    });
  });
}
