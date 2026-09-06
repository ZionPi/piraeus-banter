// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:piraeus_banter_mobile/main.dart';
import 'package:piraeus_banter_mobile/screens/home_screen.dart';

void main() {
  testWidgets('应用外壳可以启动', (WidgetTester tester) async {
    await tester.pumpWidget(const PiraeusBanterMobileApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, '泊睿妙语移动端');
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
