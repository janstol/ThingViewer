import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thingviewer/theme.dart';
import 'package:thingviewer/widgets/motion.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) => MaterialApp(
  theme: AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
    child: child!,
  ),
  home: child,
);

/// Toggles [MotionSwitcher]'s child from 'A' to 'B' on tap, so a test can
/// drive the change through the same [State] rather than replacing the
/// whole widget tree (which leaves State continuity to chance).
class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool _second = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        ElevatedButton(
          onPressed: () => setState(() => _second = true),
          child: const Text('toggle'),
        ),
        MotionSwitcher(
          child: _second
              ? const Text('B', key: ValueKey('b'))
              : const Text('A', key: ValueKey('a')),
        ),
      ],
    ),
  );
}

void main() {
  group('MotionSwitcher', () {
    testWidgets('shows its first child fully on the first frame', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const MotionSwitcher(child: Text('A'))));
      await tester.pump();

      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(MotionSwitcher),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fade.opacity.value, 1.0);
    });

    testWidgets('a later child change animates', (tester) async {
      await tester.pumpWidget(_wrap(const _Harness()));
      await tester.pump();

      await tester.tap(find.text('toggle'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Both children are still mounted mid-crossfade.
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('reduce motion makes the change instant', (tester) async {
      await tester.pumpWidget(_wrap(const _Harness(), disableAnimations: true));
      await tester.pump();

      await tester.tap(find.text('toggle'));
      await tester.pump();

      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
    });
  });

  group('ValuePulse', () {
    const restingColor = Colors.black;
    const style = TextStyle(color: restingColor);

    testWidgets('pulses on a changed value', (tester) async {
      await tester.pumpWidget(
        _wrap(const ValuePulse(value: '1', style: style)),
      );
      await tester.pump();
      expect(tester.widget<Text>(find.text('1')).style?.color, restingColor);

      await tester.pumpWidget(
        _wrap(const ValuePulse(value: '2', style: style)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final midColor = tester.widget<Text>(find.text('2')).style?.color;
      expect(midColor, isNot(restingColor));

      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text('2')).style?.color, restingColor);
    });

    testWidgets('does not pulse on a rebuild with the same value', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const ValuePulse(value: '1', style: style)),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text('1')).style?.color, restingColor);

      await tester.pumpWidget(
        _wrap(const ValuePulse(value: '1', style: style)),
      );
      await tester.pump();
      expect(tester.widget<Text>(find.text('1')).style?.color, restingColor);
    });
  });

  group('FieldLabelHero', () {
    const style = TextStyle(color: Colors.black, fontSize: 16);

    testWidgets('renders a bare Text with no Hero under reduce motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const FieldLabelHero(tag: 'x', label: 'Temp', style: style),
          disableAnimations: true,
        ),
      );
      await tester.pump();

      expect(find.text('Temp'), findsOneWidget);
      expect(find.byType(Hero), findsNothing);
    });

    testWidgets('renders a Hero carrying the given tag otherwise', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const FieldLabelHero(
            tag: 'field-label:x',
            label: 'Temp',
            style: style,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Temp'), findsOneWidget);
      final hero = tester.widget<Hero>(find.byType(Hero));
      expect(hero.tag, 'field-label:x');
    });
  });

  group('fieldLabelHeroTag', () {
    test('joins server url, channel id, and field id with |', () {
      expect(
        fieldLabelHeroTag('https://api.thingspeak.com', 1, 2),
        'field-label:https://api.thingspeak.com|1|2',
      );
    });
  });
}
