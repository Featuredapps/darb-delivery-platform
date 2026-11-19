import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Shared visual language for DARB. Keep product screens on these tokens.
abstract final class DarbColors {
  static const forest = Color(0xFF102B26);
  static const forestSoft = Color(0xFF1C443B);
  static const mint = Color(0xFFB9E4D2);
  static const lime = Color(0xFFC8F169);
  static const canvas = Color(0xFFF5F6F2);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF17231F);
  static const muted = Color(0xFF77837D);
  static const line = Color(0xFFE4E9E3);
  static const danger = Color(0xFFB94747);
}

abstract final class DarbTheme {
  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: DarbColors.forest,
      onPrimary: Colors.white,
      secondary: DarbColors.lime,
      onSecondary: DarbColors.forest,
      error: DarbColors.danger,
      onError: Colors.white,
      surface: DarbColors.surface,
      onSurface: DarbColors.ink,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: DarbColors.canvas,
      fontFamily: 'Arial',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: DarbColors.ink, fontSize: 28, fontWeight: FontWeight.w900, height: 1.2),
        headlineMedium: TextStyle(color: DarbColors.ink, fontSize: 23, fontWeight: FontWeight.w900, height: 1.25),
        titleLarge: TextStyle(color: DarbColors.ink, fontSize: 19, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(color: DarbColors.ink, fontSize: 15, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: DarbColors.ink, fontSize: 15, height: 1.5),
        bodyMedium: TextStyle(color: DarbColors.muted, fontSize: 13, height: 1.45),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: DarbColors.canvas,
        foregroundColor: DarbColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: DarbColors.ink,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: DarbColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: DarbColors.line),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: DarbColors.surface,
        indicatorColor: DarbColors.mint.withValues(alpha: .55),
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
          TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800 : FontWeight.w500,
          )),
        elevation: 0,
        height: 70,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DarbColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        hintStyle: const TextStyle(color: DarbColors.muted, fontSize: 14),
        labelStyle: const TextStyle(color: DarbColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: DarbColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: DarbColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: DarbColors.forest, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DarbColors.forest,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DarbColors.forest,
          minimumSize: const Size(0, 50),
          side: const BorderSide(color: DarbColors.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      dividerTheme: const DividerThemeData(color: DarbColors.line, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: DarbColors.forest,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
