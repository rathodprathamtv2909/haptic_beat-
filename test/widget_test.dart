import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haptic_beat/app.dart';

void main() {
  testWidgets('opens the premium player experience', (tester) async {
    await tester.pumpWidget(const HapticBeatApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('home-now-playing-card')));
    await tester.pumpAndSettle();

    expect(find.text('Reference Mix'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
    await tester.pumpAndSettle();

    expect(find.text('Signal'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
    await tester.pumpAndSettle();

    expect(find.text('Lyrics'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -520));
    await tester.pumpAndSettle();

    expect(find.text('Queue'), findsOneWidget);
  });
}
