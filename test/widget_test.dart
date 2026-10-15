import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:melodyflow/theme/app_theme.dart';

void main() {
  testWidgets('Theme renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const Scaffold(body: Center(child: Text('MelodyFlow'))),
      ),
    );
    expect(find.text('MelodyFlow'), findsOneWidget);
  });
}
