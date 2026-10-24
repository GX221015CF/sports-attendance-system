import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/group.dart';
import 'package:mobile_app/models/member.dart';
import 'package:mobile_app/pages/admin/admin_create_session_page.dart';
import 'package:mobile_app/theme/app_theme.dart';

List<TeamMember> roster(int count) => List.generate(
  count,
  (index) => TeamMember(
    id: 'fixture-$index',
    name: '合成成员${index.toString().padLeft(3, '0')}',
    groupId: 'fixture-group',
    groupName: '合成测试组',
    studentId: 'TEST-$index',
    isActive: true,
    createdAt: DateTime(2026, 10, 24),
  ),
);

Widget createPage({int count = 500}) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: AdminCreateSessionPage(
    loadGroups: () async => const [
      TeamGroup(id: 'fixture-group', name: '合成测试组'),
    ],
    loadMembers: () async => roster(count),
    publish: (_) async => 'fixture-session',
  ),
);

void main() {
  testWidgets('landscape tablet exposes roster and publish without scrolling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createPage());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('合成成员000').hitTestable(), findsOneWidget);
    expect(find.text('发布签到').hitTestable(), findsOneWidget);
    await tester.tap(find.text('合成成员000'));
    await tester.pump();
    expect(find.text('已选 1 人'), findsOneWidget);
  });

  testWidgets('large roster mounts only a viewport of selection controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createPage());
    await tester.pumpAndSettle();

    final controls = find.byType(Checkbox).evaluate().length;
    // The fixture has 500 members; mounting all controls makes each resize
    // perform work proportional to the entire roster, including invisible rows.
    expect(controls, lessThan(40));
    expect(find.text('合成成员499'), findsNothing);
  });

  testWidgets('keyboard resize preserves phone row width and input state', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(createPage(count: 20));
    await tester.pumpAndSettle();

    final search = find.widgetWithText(TextField, '按姓名搜索');
    await tester.ensureVisible(search);
    await tester.enterText(search, '合成成员0');
    await tester.pump(const Duration(milliseconds: 200));
    final card = find
        .ancestor(of: find.text('合成成员000'), matching: find.byType(InkWell))
        .first;
    final before = tester.getSize(card).width;

    // Simulates the changing Android IME inset without touching a real account.
    for (final inset in [100.0, 250.0, 400.0, 520.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
    expect(tester.getSize(card).width, before);
    expect(find.text('合成成员0'), findsOneWidget);
    expect(find.text('发布签到').hitTestable(), findsOneWidget);
  });

  testWidgets('selection survives lazy scrolling and search changes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createPage(count: 200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('合成成员000'));
    await tester.pump();
    final list = find.descendant(
      of: find.byKey(const PageStorageKey('wide-roster')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('合成成员080'),
      300,
      scrollable: list,
    );
    await tester.tap(find.text('合成成员080'));
    await tester.pump();
    expect(find.text('已选 2 人'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '按姓名搜索'), '合成成员000');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('已选 2 人'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);
    await tester.tap(find.text('清空'));
    await tester.pump();
    expect(find.text('已选 0 人'), findsOneWidget);
  });

  testWidgets('publish stays visible and disabled while roster is loading', (
    tester,
  ) async {
    final pending = Completer<List<TeamMember>>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: AdminCreateSessionPage(
          loadGroups: () async => const [],
          loadMembers: () => pending.future,
          publish: (_) async => 'fixture-session',
        ),
      ),
    );
    await tester.pump();
    final button = find.widgetWithText(ElevatedButton, '发布签到');
    expect(button.hitTestable(), findsOneWidget);
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
    pending.complete(roster(5));
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow landscape keeps the main action reachable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createPage(count: 200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('发布签到').hitTestable(), findsOneWidget);
  });

  testWidgets('tablet keyboard leaves search and publish usable', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1180, 820);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(createPage());
    await tester.pumpAndSettle();
    final search = find.widgetWithText(TextField, '按姓名搜索');
    await tester.enterText(search, '合成成员0');
    await tester.pump(const Duration(milliseconds: 200));
    tester.view.viewInsets = const FakeViewPadding(bottom: 520);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(search.hitTestable(), findsOneWidget);
    expect(find.text('发布签到').hitTestable(), findsOneWidget);
  });
}
