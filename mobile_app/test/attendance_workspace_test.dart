import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/attendance_session.dart';
import 'package:mobile_app/models/session_member.dart';
import 'package:mobile_app/pages/offline_session_page.dart';
import 'package:mobile_app/pages/session_member_list_page.dart';
import 'package:mobile_app/services/attendance_service.dart';
import 'package:mobile_app/theme/app_theme.dart';
import 'package:mobile_app/widgets/member_card.dart';

import 'offline_ui_test.dart' show UiLocal;

AttendanceSession signingSession() => AttendanceSession(
  id: 'session',
  title: '横屏训练 · 合成测试任务',
  requiredTime: DateTime.now().add(const Duration(hours: 1)),
  endTime: DateTime.now().add(const Duration(hours: 2)),
  status: 'active',
  createdAt: DateTime.now(),
);

List<SessionMember> signingRoster({int count = 500, String remark = ''}) =>
    List.generate(
      count,
      (index) => SessionMember(
        id: 'record-$index',
        sessionId: 'session',
        memberId: 'member-$index',
        status: ['pending', 'normal', 'late', 'absent'][index % 4],
        checkinTime: index % 4 == 1 || index % 4 == 2
            ? DateTime(2026, 10, 24, 16)
            : null,
        lateMinutes: index % 4 == 2 ? 2 : 0,
        memberName: '合成成员${index.toString().padLeft(3, '0')}',
        studentId: 'TEST-${index.toString().padLeft(3, '0')}',
        gender: '',
        phone: '',
        groupName: '合成测试组',
        remark: remark,
      ),
    );

class SigningCloud implements AttendanceService {
  int writes = 0;
  String remark = '';
  @override
  Future<bool> closeExpiredSessionIfNeeded(AttendanceSession session) async =>
      false;
  @override
  Future<List<SessionMember>> getSessionMembers(String sessionId) async =>
      signingRoster(remark: remark);
  @override
  Future<void> updateSessionMemberRemark({
    required String sessionMemberId,
    required String? remark,
  }) async {
    writes++;
    this.remark = remark ?? '';
  }

  @override
  Future<void> checkinMember({
    required String sessionMemberId,
    required String status,
    required DateTime checkinTime,
    required int lateMinutes,
  }) async {
    writes++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SigningLocal extends UiLocal {
  int writes = 0;
  @override
  Future<List<SessionMember>> getMembers(String id) async =>
      signingRoster(remark: remark);
  @override
  Future<SessionMember> checkin(String sessionId, String recordId) async {
    writes++;
    return (await getMembers(sessionId)).first;
  }
}

Widget signingPage(bool local, {SigningCloud? cloud, SigningLocal? device}) =>
    local
    ? OfflineSessionPage(local: device ?? SigningLocal(), sessionId: 'session')
    : SessionMemberListPage(
        session: signingSession(),
        attendanceService: cloud ?? SigningCloud(),
      );

Widget signingApp(Widget page, {double scale = 1}) => MaterialApp(
  theme: AppTheme.lightTheme,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: page,
);

void main() {
  for (final local in [false, true]) {
    final mode = local ? 'local' : 'online';
    for (final size in [const Size(1180, 820), const Size(800, 360)]) {
      testWidgets(
        '$mode at $size exposes signing and only mounts visible rows',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(signingApp(signingPage(local)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('合成成员000').hitTestable(), findsOneWidget);
          expect(
            find.widgetWithText(ElevatedButton, '签到').first.hitTestable(),
            findsOneWidget,
          );
          expect(find.byType(MemberCard).evaluate().length, lessThan(30));
          expect(find.text('合成成员499'), findsNothing);
        },
      );
    }

    testWidgets(
      '$mode tablet keeps search and member width stable with keyboard',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1180, 820);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(signingApp(signingPage(local)));
        await tester.pumpAndSettle();
        final before = tester.getSize(find.byType(MemberCard).first).width;
        final search = find.byType(TextField);
        await tester.enterText(search, '合成成员0');
        tester.view.viewInsets = const FakeViewPadding(bottom: 520);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.byType(MemberCard).first).width, before);
        expect(search.hitTestable(), findsOneWidget);
        expect(tester.widget<TextField>(search).controller!.text, '合成成员0');
      },
    );

    testWidgets(
      '$mode keeps filter and query across rotation and recovers empty results',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1180, 820));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(signingApp(signingPage(local)));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '合成成员00');
        await tester.tap(find.widgetWithText(ChoiceChip, '正常'));
        await tester.pumpAndSettle();
        expect(find.text('合成成员000'), findsNothing);
        expect(find.text('合成成员001'), findsOneWidget);
        await tester.binding.setSurfaceSize(const Size(420, 900));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '合成成员00',
        );
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '正常'))
              .selected,
          isTrue,
        );
        await tester.ensureVisible(find.byType(TextField));
        await tester.enterText(find.byType(TextField), '无匹配合成姓名');
        await tester.pumpAndSettle();
        expect(find.text('没有匹配成员'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '合成成员00');
        await tester.pumpAndSettle();
        expect(find.text('合成成员001'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$mode large text and long notes have no fixed card height overflow',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1180, 820));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          signingApp(
            signingPage(
              local,
              device: SigningLocal()..remark = '用于横屏检查的较长合成备注，训练前请核对。',
            ),
            scale: 1.6,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('合成成员000').hitTestable(), findsOneWidget);
      },
    );

    testWidgets('$mode scrolling roster keeps tablet search visible', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1180, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(signingApp(signingPage(local)));
      await tester.pumpAndSettle();
      final scrollable = find.descendant(
        of: find.byKey(const PageStorageKey('attendance-roster')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('合成成员080'),
        400,
        scrollable: scrollable,
      );
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      expect(find.text('任务进行中').hitTestable(), findsOneWidget);
      expect(find.byType(MemberCard).evaluate().length, lessThan(30));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$mode landscape remark saves with the keyboard open', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1180, 820);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      final cloud = SigningCloud();
      final device = SigningLocal();
      await tester.pumpWidget(
        signingApp(signingPage(local, cloud: cloud, device: device)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, '编辑备注').first);
      await tester.pumpAndSettle();
      final field = find.widgetWithText(TextField, '请输入备注，可留空');
      await tester.enterText(field, '横屏合成备注');
      tester.view.viewInsets = const FakeViewPadding(bottom: 520);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('保存'));
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(local ? device.remark : cloud.remark, '横屏合成备注');
      expect(tester.takeException(), isNull);
    });

    testWidgets('$mode canceling check-in writes nothing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1180, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cloud = SigningCloud();
      final device = SigningLocal();
      await tester.pumpWidget(
        signingApp(signingPage(local, cloud: cloud, device: device)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '签到').first);
      await tester.pumpAndSettle();
      expect(find.text('确认签到'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(cloud.writes + device.writes, 0);
    });
  }
}
