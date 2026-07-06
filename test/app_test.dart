import 'package:flutter_test/flutter_test.dart';
import 'package:haptic_beat/app.dart';

void main() {
  testWidgets('renders the home experience', (tester) async {
    await tester.pumpWidget(const HapticBeatApp());
    await tester.pump();

    expect(find.text('HapticBeat'), findsOneWidget);
    expect(find.text('Now Playing'), findsOneWidget);
    expect(find.text('BPM'), findsOneWidget);
  });
}
