import 'package:flutter/material.dart';

const forest = Color(0xff1f4d32);
const gold = Color(0xffc4a35a);
const parchment = Color(0xfff4efe4);
const ink = Color(0xff172117);

ThemeData lightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: forest,
    primary: forest,
    secondary: gold,
    surface: parchment,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: parchment,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: forest,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: gold.withValues(alpha: 0.35),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: ink),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: forest,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}

ThemeData darkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff8fcb9b),
    primary: const Color(0xff8fcb9b),
    secondary: gold,
    surface: const Color(0xff121a14),
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xff0f1511),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Color(0xff152018),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xff1b261e),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
