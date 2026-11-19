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

    test('includes semantic status colors', () {
      expect(DarbColors.success, isA<Color>());
      expect(DarbColors.warning, isA<Color>());
      expect(DarbColors.info, isA<Color>());
      expect(DarbColors.borderStrong, isA<Color>());
      expect(DarbColors.scrim, isA<Color>());
    });
  });
}
