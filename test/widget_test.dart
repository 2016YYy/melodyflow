import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:melodyflow/theme/app_theme.dart';
import 'package:melodyflow/widgets/section_tiles.dart';

void main() {
  test('所有配色均可构建深色 / 浅色主题', () {
    for (final palette in ThemePalettes.all) {
      final light = AppTheme.buildTheme(palette, false);
      final dark = AppTheme.buildTheme(palette, true);
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.colorScheme.primary, isNotNull);
      expect(dark.colorScheme.primary, isNotNull);
      expect(light.useMaterial3, isTrue);
      expect(dark.useMaterial3, isTrue);
    }
  });

  test('圆角与间距规范取值合理', () {
    expect(AppRadius.xs < AppRadius.sm, isTrue);
    expect(AppRadius.sm < AppRadius.md, isTrue);
    expect(AppRadius.md < AppRadius.lg, isTrue);
    expect(AppRadius.lg < AppRadius.xl, isTrue);
    expect(AppRadius.pill, greaterThanOrEqualTo(100));
    expect(AppSpace.xs < AppSpace.sm, isTrue);
    expect(AppSpace.sm < AppSpace.md, isTrue);
    expect(AppSpace.md < AppSpace.lg, isTrue);
    expect(AppSpace.lg < AppSpace.xl, isTrue);
  });

  testWidgets('应用在浅色主题下可正常渲染', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(ThemePalettes.purple, false),
        home: const Scaffold(body: Center(child: Text('MelodyFlow'))),
      ),
    );
    expect(find.text('MelodyFlow'), findsOneWidget);
  });

  testWidgets('分组组件在深色 / 浅色主题下均可渲染', (WidgetTester tester) async {
    for (final dark in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(ThemePalettes.ocean, dark),
          home: Scaffold(
            body: ListView(
              children: [
                const SectionHeader('外观'),
                ActionTile(
                  icon: Icons.palette_rounded,
                  title: '主题配色',
                  subtitle: '梦幻紫',
                  palette: ThemePalettes.purple,
                  onTap: () {},
                ),
                SwitchTile(
                  icon: Icons.dark_mode_rounded,
                  title: '深色模式',
                  subtitle: '切换深色 / 浅色主题',
                  value: dark,
                  palette: ThemePalettes.purple,
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('外观'), findsOneWidget);
      expect(find.text('主题配色'), findsOneWidget);
      expect(find.text('深色模式'), findsOneWidget);
    }
  });
}
