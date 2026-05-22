// test/widget_test.dart
// Default Flutter smoke test — updated for equinox_flood package name.
import 'package:equinox_flood/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test — widget tree pumps without exception',
      (WidgetTester tester) async {
    await tester.pumpWidget(const OpsFloodApp());
    // If the widget tree builds without throwing, the test passes.
    expect(find.byType(OpsFloodApp), findsOneWidget);
  });
}
