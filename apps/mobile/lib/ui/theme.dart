import 'package:flutter/material.dart';

import 'site.dart';

ThemeData lightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: siteGreenSolid,
    primary: siteGreenSolid,
    secondary: siteGreenTop,
    surface: siteCanvas,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: siteCanvas,
    fontFamily: 'Lucida Grande',
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      backgroundColor: siteCanvas,
      foregroundColor: siteGreen,
      elevation: 0,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: siteGreenTop,
      inactiveTrackColor: siteGreenBottom.withValues(alpha: 0.35),
      thumbColor: siteGreenSolid,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: siteGreenSolid,
        foregroundColor: siteButtonText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}

ThemeData darkTheme() => lightTheme();
