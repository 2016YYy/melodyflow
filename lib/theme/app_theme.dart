import 'package:flutter/material.dart';

/// 主题配色方案
class ThemePalette {
  final String name;
  final String label;
  final Color primary;
  final Color secondary;
  final Color accent;
  final List<Color> gradient;
  final List<Color> coverPlaceholder;

  const ThemePalette({
    required this.name,
    required this.label,
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.gradient,
    required this.coverPlaceholder,
  });
}

/// 预设主题配色
class ThemePalettes {
  static const ThemePalette purple = ThemePalette(
    name: 'purple',
    label: '梦幻紫',
    primary: Color(0xFF6C63FF),
    secondary: Color(0xFF9333EA),
    accent: Color(0xFFEC4899),
    gradient: [Color(0xFF6C63FF), Color(0xFF9333EA)],
    coverPlaceholder: [Color(0xFF6C63FF), Color(0xFF9333EA), Color(0xFFEC4899)],
  );

  static const ThemePalette ocean = ThemePalette(
    name: 'ocean',
    label: '海洋蓝',
    primary: Color(0xFF3B82F6),
    secondary: Color(0xFF06B6D4),
    accent: Color(0xFF22D3EE),
    gradient: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
    coverPlaceholder: [Color(0xFF3B82F6), Color(0xFF06B6D4), Color(0xFF22D3EE)],
  );

  static const ThemePalette emerald = ThemePalette(
    name: 'emerald',
    label: '翡翠绿',
    primary: Color(0xFF10B981),
    secondary: Color(0xFF059669),
    accent: Color(0xFF34D399),
    gradient: [Color(0xFF10B981), Color(0xFF059669)],
    coverPlaceholder: [Color(0xFF10B981), Color(0xFF059669), Color(0xFF34D399)],
  );

  static const ThemePalette sunset = ThemePalette(
    name: 'sunset',
    label: '日落橙',
    primary: Color(0xFFF97316),
    secondary: Color(0xFFEF4444),
    accent: Color(0xFFFB923C),
    gradient: [Color(0xFFF97316), Color(0xFFEF4444)],
    coverPlaceholder: [Color(0xFFF97316), Color(0xFFEF4444), Color(0xFFFB923C)],
  );

  static const ThemePalette rose = ThemePalette(
    name: 'rose',
    label: '玫瑰粉',
    primary: Color(0xFFEC4899),
    secondary: Color(0xFFF43F5E),
    accent: Color(0xFFF472B6),
    gradient: [Color(0xFFEC4899), Color(0xFFF43F5E)],
    coverPlaceholder: [Color(0xFFEC4899), Color(0xFFF43F5E), Color(0xFFF472B6)],
  );

  static const ThemePalette amber = ThemePalette(
    name: 'amber',
    label: '琥珀金',
    primary: Color(0xFFF59E0B),
    secondary: Color(0xFFD97706),
    accent: Color(0xFFFBBF24),
    gradient: [Color(0xFFF59E0B), Color(0xFFD97706)],
    coverPlaceholder: [Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFFFBBF24)],
  );

  static const List<ThemePalette> all = [
    purple,
    ocean,
    emerald,
    sunset,
    rose,
    amber,
  ];

  static ThemePalette fromName(String name) =>
      all.firstWhere((p) => p.name == name, orElse: () => purple);
}

/// 播放器皮肤
class PlayerSkin {
  final String name;
  final String label;

  const PlayerSkin({required this.name, required this.label});

  static const PlayerSkin classic = PlayerSkin(name: 'classic', label: '经典');
  static const PlayerSkin modern = PlayerSkin(name: 'modern', label: '现代');
  static const PlayerSkin minimal = PlayerSkin(name: 'minimal', label: '极简');
  static const PlayerSkin vinyl = PlayerSkin(name: 'vinyl', label: '黑胶');

  static const List<PlayerSkin> all = [classic, modern, minimal, vinyl];

  static PlayerSkin fromName(String name) =>
      all.firstWhere((s) => s.name == name, orElse: () => modern);
}

/// 应用主题构建器
class AppTheme {
  static ThemeData buildTheme(ThemePalette palette, bool dark) {
    if (dark) {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: palette.primary,
        colorScheme: ColorScheme.dark(
          primary: palette.primary,
          secondary: palette.secondary,
          tertiary: palette.accent,
          surface: const Color(0xFF1A1A2E),
          error: const Color(0xFFEF4444),
        ),
        scaffoldBackgroundColor: const Color(0xFF12121F),
        cardColor: const Color(0xFF1E1E36),
        dividerColor: Colors.white10,
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          headlineMedium: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          titleLarge: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
          titleMedium: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          bodyLarge: TextStyle(fontSize: 16, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
          bodySmall: TextStyle(fontSize: 12, color: Colors.white54),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: palette.primary,
          inactiveTrackColor: Colors.white12,
          thumbColor: Colors.white,
          overlayColor: palette.primary.withValues(alpha:0.25),
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1A1A2E),
          indicatorColor: palette.primary.withValues(alpha:0.2),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          iconTheme: WidgetStateProperty.all(
            const IconThemeData(color: Colors.white54),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E36),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: Colors.white38),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E36),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    } else {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: palette.primary,
        colorScheme: ColorScheme.light(
          primary: palette.primary,
          secondary: palette.secondary,
          tertiary: palette.accent,
          surface: Colors.white,
          error: const Color(0xFFEF4444),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5FA),
        cardColor: Colors.white,
        dividerColor: Colors.black12,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
          surfaceTintColor: Colors.transparent,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
          headlineMedium: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          titleLarge: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87),
          titleMedium: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
          bodyLarge: TextStyle(fontSize: 16, color: Colors.black87),
          bodyMedium: TextStyle(fontSize: 14, color: Colors.black54),
          bodySmall: TextStyle(fontSize: 12, color: Colors.black38),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: palette.primary,
          inactiveTrackColor: Colors.black12,
          thumbColor: palette.primary,
          overlayColor: palette.primary.withValues(alpha:0.2),
          trackHeight: 4,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        ),
        iconTheme: const IconThemeData(color: Colors.black54),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: palette.primary.withValues(alpha:0.15),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF0F0F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: Colors.black38),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }
  }
}
