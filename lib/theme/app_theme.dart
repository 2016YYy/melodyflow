import 'package:flutter/material.dart';

/// 应用主题
class AppTheme {
  // 主题色 - 紫蓝渐变
  static const Color primary = Color(0xFF6C63FF);
  static const Color secondary = Color(0xFF9333EA);
  static const Color accent = Color(0xFFEC4899);

  // 深色主题
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primary,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: Color(0xFF1A1A2E),
      error: Color(0xFFEF4444),
    ),
    scaffoldBackgroundColor: const Color(0xFF16162A),
    cardColor: const Color(0xFF1E1E36),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1A1A2E),
      elevation: 0,
      centerTitle: true,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primary,
      inactiveTrackColor: Colors.white24,
      thumbColor: Colors.white,
      overlayColor: primary.withOpacity(0.3),
    ),
    iconTheme: const IconThemeData(color: Colors.white70),
  );

  // 浅色主题
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primary,
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: secondary,
      surface: Colors.white,
      error: Color(0xFFEF4444),
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F5FA),
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      foregroundColor: Colors.black87,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: Colors.black54),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primary,
      inactiveTrackColor: Colors.black12,
      thumbColor: primary,
      overlayColor: primary.withOpacity(0.3),
    ),
  );

  /// 渐变背景
  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C63FF), Color(0xFF9333EA)],
  );

  /// 封面占位色
  static const List<Color> coverPlaceholder = [
    Color(0xFF6C63FF),
    Color(0xFF9333EA),
    Color(0xFFEC4899),
  ];
}
