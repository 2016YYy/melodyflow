import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:melodyflow/main.dart';

void main() {
  testWidgets('App launches and shows home screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MelodyFlowApp());
    // 验证应用标题显示
    expect(find.text('MelodyFlow'), findsOneWidget);
  });
}
