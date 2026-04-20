import 'package:flutter_test/flutter_test.dart';
import 'package:netpulse/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const NetPulseApp());

    // Verify that the app title is present
    expect(find.text('NetPulse'), findsOneWidget);
  });
}
