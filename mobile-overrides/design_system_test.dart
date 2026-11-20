import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:darb/design_system.dart';

void main() {
  group('DARB design system', () {
    test('defines the approved Material 3 theme', () {
      final theme = DarbTheme.light;
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, DarbColors.forest);
      expect(theme.scaffoldBackgroundColor, DarbColors.canvas);
    });

    test('provides consistent spacing, radius and motion tokens', () {
      expect(DarbSpace.xs, 8);
      expect(DarbSpace.md, 16);
      expect(DarbRadius.md, 16);
      expect(DarbRadius.hero, 36);
      expect(DarbMotion.fast, const Duration(milliseconds: 160));
      expect(DarbMotion.standard, const Duration(milliseconds: 260));
    });

    test('provides rich motion timings and reduced-motion support', () {
      expect(DarbMotion.press.inMilliseconds, 120);
      expect(DarbMotion.route.inMilliseconds, 340);
      expect(DarbMotion.staggerDelay(3).inMilliseconds, 165);
    });

    testWidgets('DarbFadeSlide skips entrance motion when reduced motion is on', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: DarbFadeSlide(child: Text('DARB motion')),
            ),
          ),
        ),
      );

      final fadeFinder = find.descendant(
        of: find.byType(DarbFadeSlide),
        matching: find.byType(FadeTransition),
      );
      expect(fadeFinder, findsOneWidget);

      final fade = tester.widget<FadeTransition>(fadeFinder);
      expect(fade.opacity.value, 1);
    });

    test('includes semantic status colors', () {
      expect(DarbColors.success, isA<Color>());
      expect(DarbColors.warning, isA<Color>());
      expect(DarbColors.info, isA<Color>());
      expect(DarbColors.borderStrong, isA<Color>());
      expect(DarbColors.scrim, isA<Color>());
    });
  });
}
