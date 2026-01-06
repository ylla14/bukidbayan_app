import 'package:flutter/material.dart';

// const lightColorScheme = ColorScheme(
//   brightness: Brightness.light,
//   primary: Color(0xFF416FDF),
//   onPrimary: Color(0xFFFFFFFF),
//   secondary: Color(0xFF6EAEE7),
//   onSecondary: Color(0xFFFFFFFF),
//   error: Color(0xFFBA1A1A),
//   onError: Color(0xFFFFFFFF),
//   background: Color(0xFFFCFDF6),
//   onBackground: Color(0xFF1A1C18),
//   shadow: Color(0xFF000000),
//   outlineVariant: Color(0xFFC2C8BC),
//   surface: Color(0xFFF9FAF3),
//   onSurface: Color(0xFF1A1C18),
// );

const lightColorScheme = ColorScheme(
  brightness: Brightness.light,

  // Primary colors
  primary: Color(0xFF21825C),
  onPrimary: Color(0xFFF9F9F9),

  secondary: Color(0xFFA4D792),
  onSecondary: Color(0xFF424141),

  // Error (UNCHANGED)
  error: Color(0xFFBA1A1A),
  onError: Color(0xFFFFFFFF),

  // Backgrounds
  background: Color(0xFFF9F9F9),
  onBackground: Color(0xFF424141),

  surface: Color(0xFFF7FDB6),
  onSurface: Color(0xFF424141),

  // Misc
  shadow: Color(0xFF000000),
  outlineVariant: Color(0xFFA4D792),
);


const darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF416FDF),
  onPrimary: Color(0xFFFFFFFF),
  secondary: Color(0xFF6EAEE7),
  onSecondary: Color(0xFFFFFFFF),
  error: Color(0xFFBA1A1A),
  onError: Color(0xFFFFFFFF),
  background: Color(0xFFFCFDF6),
  onBackground: Color(0xFF1A1C18),
  shadow: Color(0xFF000000),
  outlineVariant: Color(0xFFC2C8BC),
  surface: Color(0xFFF9FAF3),
  onSurface: Color(0xFF1A1C18),
);

ThemeData lightMode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: lightColorScheme,
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStatePropertyAll<Color>(
        lightColorScheme.primary, // Slightly darker shade for the button
      ),
      foregroundColor:
          WidgetStatePropertyAll<Color>(Colors.white), // text color
      elevation: WidgetStatePropertyAll<double>(5.0), // shadow
      padding: WidgetStatePropertyAll<EdgeInsets>(
          const EdgeInsets.symmetric(horizontal: 20, vertical: 18)),
      shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // Adjust as needed
        ),
      ),
    ),
  ),
);

ThemeData darkMode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: darkColorScheme,
);