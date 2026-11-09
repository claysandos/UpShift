import 'package:flutter/material.dart';

class AppTheme {
  /// Widget Colors
  static const Color widgetBackground = Color(0xFF10191F);
  static const Color widgetBorder = Color(0xFF29434D);
  static const Color widgetCyanAccent = Color(0xFF43D9F5);
  static const Color widgetMintAccent = Color(0xFF52DDA5);
  static const Color widgetLabel = Color(0xFF78929B);

  /// Text Styles
  static const gearStyle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    fontStyle: FontStyle.italic,
    height: 1,
  );

  static const labelStyle = TextStyle(
    color: widgetLabel,
    fontSize: 10,
    fontWeight: FontWeight.bold,
    letterSpacing: 2.0,
    fontFamily: 'monospace',
  );

  static const unitStyle = TextStyle(
    color: appDim,
    fontSize: 10,
    fontWeight: FontWeight.bold,
    letterSpacing: 2.0,
    fontFamily: 'monospace',
  );

  static const clickableTextStyle = TextStyle(
    color: appDim,
    fontSize: 12,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.3,
    fontFamily: 'monospace',
  );

  /// Button Style
  static const ButtonStyle buttonStyle = ButtonStyle(
    foregroundColor: WidgetStatePropertyAll(AppTheme.appDim),
    backgroundColor: WidgetStatePropertyAll(AppTheme.widgetBackground),
    side: WidgetStatePropertyAll(
      BorderSide(color: AppTheme.widgetBorder, width: 1.2),
    ),
  );

  /// App Colors
  static const Color appBackground = Colors.black;
  static const Color appDim = Color(0x80F2F4F7);
  static const Color appWhite = Color(0xFFFFFFFF);
  static const Color green = Color(0xFF22D66B);
  static const Color amber = Color(0xFFFFD11A);
  static const Color red = Color(0xFFFF2D2D);

  /// App Theme
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: appBackground,
    primaryColor: Colors.white,
    colorScheme: const ColorScheme.dark(
      primary: Colors.white,
      surface: appBackground,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: appBackground,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );
}
