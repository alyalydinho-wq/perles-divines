import 'package:flutter/material.dart';

import 'site.dart';

/// Seul thème de l’app : elle reste claire même en mode sombre.
ThemeData lightTheme() {
  const palette = SitePalette.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: siteGreenSolid,
    primary: palette.accent,
    onPrimary: palette.onGreen,
    secondary: palette.greenTop,
    surface: palette.canvas,
    onSurface: palette.ink,
    error: palette.error,
    brightness: Brightness.light,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
  );
  return base.copyWith(
    scaffoldBackgroundColor: palette.canvas,
    canvasColor: palette.canvas,
    extensions: const [palette],
    textTheme: base.textTheme.apply(
      fontFamily: 'Lucida Grande',
      bodyColor: palette.ink,
      displayColor: palette.ink,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      backgroundColor: siteCanvas,
      foregroundColor: siteGreen,
      elevation: 0,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: palette.accent,
      inactiveTrackColor: palette.track,
      thumbColor: palette.accent,
    ),
    popupMenuTheme: const PopupMenuThemeData(color: siteCanvas),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.fill,
        foregroundColor: palette.onGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}
