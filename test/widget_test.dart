// test/widget_test.dart
// App-level smoke test — verifies widget tree pumps without exception.
import 'package:equinox_flood/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test — OpsFloodApp pumps without exception',
      (WidgetTester tester) async {
    // ProviderScope is required because OpsFloodApp is a ConsumerWidget.
    await tester.pumpWidget(
      const ProviderScope(child: OpsFloodApp()),
    );
    expect(find.byType(OpsFloodApp), findsOneWidget);
  });
}
