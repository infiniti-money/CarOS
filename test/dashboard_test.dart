import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:infiniti_caros/main.dart';

void main() {
  testWidgets('Dashboard tiếng Việt không giả dữ liệu xe', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(InfinitiApp(prefs: prefs));
    expect(find.text('INFINITI'), findsOneWidget);
    expect(find.text('— km/h'), findsOneWidget);
    expect(find.text('GPS chưa tích hợp'), findsOneWidget);
    await tester.tap(find.byTooltip('Đổi chế độ sáng tối'));
    await tester.pumpAndSettle();
    expect(prefs.getBool('dark'), false);
  });
}
