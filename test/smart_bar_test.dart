import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infiniti_caros/smart_bar.dart';

void main() {
  testWidgets('Launcher fallback routes application labels', (tester) async {
    final actions = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SmartBar(
      dark: true, glass: false, launcherItems: const ['Bản đồ'], columns: 2,
      fallback: TextButton(onPressed: () => actions.add('Bản đồ'), child: const Text('Bản đồ')),
      onAction: actions.add,
    ))));
    await tester.tap(find.text('Bản đồ'));
    expect(actions, ['Bản đồ']);
  });
  testWidgets('Flutter fallback sends known Vietnamese actions', (tester) async {
    final actions = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SmartBar(dark: true, glass: true, onAction: actions.add))));
    await tester.tap(find.byTooltip('Bản đồ'));
    await tester.tap(find.byTooltip('Trợ lý tiếng Việt'));
    await tester.tap(find.byTooltip('Đổi chế độ sáng tối'));
    expect(actions, ['map','voice','theme']);
    expect(tester.takeException(), isNull);
  });
}
