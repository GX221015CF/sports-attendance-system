import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/app.dart';

void main() {
  testWidgets('shows app placeholder page', (WidgetTester tester) async {
    await tester.pumpWidget(const SportsAttendanceApp());

    expect(find.text('运动队签到'), findsWidgets);
    expect(find.text('Flutter App 基础配置完成'), findsOneWidget);
  });
}
