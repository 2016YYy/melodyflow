import 'package:flutter/material.dart';

/// 主题配色方案（种子色驱动整套 Material You 配色）
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

/// 统一圆角规范
class AppRadius {
  static const double xs = 10;
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;
}

/// 统一间距规范
class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
}

/// 应用主题构建器 - 以种子色生成一整套和谐的 Material You 主题
class AppTheme {
  /// 深色表面基色
  static const Color _darkBg = Color(0xFF0B0B0F);

  static ThemeData buildTheme(ThemePalette palette, bool dark) {
    final brightness = dark ? Brightness.dark : Brightness.light;

    // 以种子色生成整套配色，再微调表面基色，形成统一的深/浅色底
    ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
      primary: palette.primary,
      secondary: palette.secondary,
      tertiary: palette.accent,
    );

    if (dark) {
      scheme = scheme.copyWith(
        surface: const Color(0xFF15151B),
        onSurface: const Color(0xFFECECF1),
        onSurfaceVariant: const Color(0xFF9E9EA8),
        outlineVariant: const Color(0xFF2A2A33),
      );
    } else {
      scheme = scheme.copyWith(
        surface: Colors.white,
        onSurface: const Color(0xFF1A1A1F),
        onSurfaceVariant: const Color(0xFF6B6B76),
        outlineVariant: const Color(0xFFE7E7EE),
      );
    }

    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;

    final textTheme = TextTheme(
      displaySmall: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: onSurface),
      headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          color: onSurface),
      headlineMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: onSurface),
      headlineSmall: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w600, color: onSurface),
      titleLarge: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600, color: onSurface),
      titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: onSurface),
      titleSmall: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: onSurface),
      bodyLarge: TextStyle(fontSize: 16, height: 1.4, color: onSurface),
      bodyMedium: TextStyle(
          fontSize: 14, height: 1.4, color: onSurfaceVariant),
      bodySmall: TextStyle(
          fontSize: 12.5, height: 1.35, color: onSurfaceVariant),
      labelLarge: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: onSurface),
      labelMedium: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500, color: onSurfaceVariant),
      labelSmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w500, color: onSurfaceVariant),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? _darkBg : const Color(0xFFF7F7FB),
      canvasColor: dark ? _darkBg : const Color(0xFFF7F7FB),
      cardColor: dark ? const Color(0xFF1A1A21) : Colors.white,
      dividerColor: scheme.outlineVariant.withValues(alpha: 0.6),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: onSurface, size: 24),
      ),
      iconTheme: IconThemeData(color: onSurfaceVariant, size: 24),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF1A1A21) : Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xFF1C1C24) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? const Color(0xFF1C1C24) : Colors.white,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: dark ? const Color(0xFF1C1C24) : Colors.white,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark
            ? const Color(0xFF21212A)
            : const Color(0xFFEFEFF5),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: dark
            ? const Color(0xFF21212A)
            : const Color(0xFFEFEFF5),
        selectedColor: scheme.primary,
        side: BorderSide.none,
        labelStyle: textTheme.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.outlineVariant.withValues(alpha: 0.5),
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.18),
        trackHeight: 4,
        thumbShape:
            const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape:
            const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.outlineVariant.withValues(alpha: 0.5),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: dark ? const Color(0xFF1C1C24) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: textTheme.bodyLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF15151B) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.all(textTheme.labelSmall),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? scheme.primary : onSurfaceVariant,
          );
        }),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onSurfaceVariant,
        textColor: onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.outlineVariant;
        }),
        trackOutlineColor:
            const WidgetStatePropertyAll(Colors.transparent),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: onSurfaceVariant,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: textTheme.titleSmall,
        unselectedLabelStyle: textTheme.titleSmall,
      ),
    );
  }
}
