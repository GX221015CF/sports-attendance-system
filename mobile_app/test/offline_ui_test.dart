import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mobile_app/models/attendance_session.dart';
import 'package:mobile_app/models/group.dart';
import 'package:mobile_app/models/member.dart';
import 'package:mobile_app/models/offline_session.dart';
import 'package:mobile_app/models/session_member.dart';
import 'package:mobile_app/pages/admin/admin_create_session_page.dart';
import 'package:mobile_app/pages/mode_home_page.dart';
import 'package:mobile_app/pages/offline_home_page.dart';
import 'package:mobile_app/pages/offline_session_page.dart';
import 'package:mobile_app/services/offline_attendance_service.dart';
import 'package:mobile_app/services/offline_store.dart';
import 'package:mobile_app/services/time_service.dart';
import 'package:mobile_app/theme/app_theme.dart';
import 'package:mobile_app/widgets/checkin_confirm_dialog.dart';

// UI fixtures have no Supabase initialization or network dependency.
class UiLocal extends OfflineAttendanceService {
  UiLocal()
    : super(
        store: OfflineStore(factory: databaseFactoryFfi),
        scope: 'ui-test',
      );
  bool offline = false;
  bool closed = false;
  bool locked = false;
  int reads = 0;
  String remark = '';
  final time = DateTime.now();

  @override
  Future<bool> getOfflineMode() async => offline;
  @override
  Future<void> setOfflineMode(bool value) async => offline = value;
  @override
  Future<OfflineRoster?> getRoster() async => OfflineRoster(
    ownerId: 'ui-owner',
    savedAt: time,
    groups: const [TeamGroup(id: 'group', name: '测试组')],
    members: [
      TeamMember(
        id: 'member',
        name: '测试成员',
        isActive: true,
        createdAt: time,
        groupId: 'group',
        groupName: '测试组',
        studentId: 'TEST',
      ),
    ],
  );
  @override
  Future<OfflineSession> getSession(String id) async => OfflineSession(
    session: AttendanceSession(
      id: 'session',
      title: '本机测试任务',
      requiredTime: time.add(const Duration(hours: 1)),
      endTime: time.add(const Duration(hours: 2)),
      status: closed ? 'closed' : 'active',
      createdAt: time,
    ),
    ownerId: 'ui-owner',
    syncState: locked ? 'failed' : 'local',
    locked: locked,
    closedAt: closed ? time : null,
  );
  @override
  Future<List<OfflineSession>> listSessions() async {
    reads++;
    return [await getSession('session')];
  }

  @override
  Future<void> closeSession(String id, {bool onlyIfExpired = false}) async {
    if (!onlyIfExpired) closed = true;
  }

  @override
  Future<List<SessionMember>> getMembers(String id) async => [
    SessionMember(
      id: 'record',
      sessionId: 'session',
      memberId: 'member',
      status: closed ? 'absent' : 'pending',
      checkinTime: null,
      lateMinutes: 0,
      memberName: '测试成员',
      studentId: 'TEST',
      gender: '',
      phone: '',
      groupName: '测试组',
      remark: remark,
    ),
  ];
  @override
  Future<void> saveRemark(
    String sessionId,
    String recordId,
    String value,
  ) async {
    if (locked) throw StateError('locked');
    remark = value;
  }
}

void main() {
  Widget app(Widget home) =>
      MaterialApp(theme: AppTheme.lightTheme, home: home);

  testWidgets('check-in confirmation remains usable in landscape', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final local = UiLocal();
    final member = (await local.getMembers('session')).first;
    await tester.pumpWidget(
      app(
        CheckinConfirmDialog(
          member: member,
          now: local.time,
          preview: TimeService().previewCheckin(
            now: local.time,
            requiredTime: local.time.add(const Duration(hours: 1)),
            endTime: local.time.add(const Duration(hours: 2)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('确认签到'));
    expect(find.text('确认签到').hitTestable(), findsOneWidget);
  });

  testWidgets(
    'explicit mode selection persists and restores without a cloud client',
    (tester) async {
      final local = UiLocal();
      await tester.pumpWidget(app(ModeHomePage(local: local)));
      await tester.pumpAndSettle();
      expect(find.text('在线模式 · 实时读取云端'), findsOneWidget);
      await tester.tap(find.text('离线模式'));
      await tester.pumpAndSettle();
      expect(local.offline, isTrue);
      expect(find.byType(OfflineHomePage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(ModeHomePage(local: local)));
      await tester.pumpAndSettle();
      expect(find.byType(OfflineHomePage), findsOneWidget);
      await tester.tap(find.text('切回在线'));
      await tester.pumpAndSettle();
      expect(local.offline, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(360, 800), const Size(800, 360)]) {
    testWidgets('offline home at $size offers sync only after local end', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final local = UiLocal();
      await tester.pumpWidget(
        app(OfflineHomePage(local: local, onGoOnline: () {})),
      );
      await tester.pumpAndSettle();
      expect(find.text('手动同步'), findsNothing);
      expect(find.text('进行中 · 仅保存在本机'), findsOneWidget);
      local.closed = true;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        app(OfflineHomePage(local: local, onGoOnline: () {})),
      );
      await tester.pumpAndSettle();
      expect(find.text('手动同步'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'offline creation uses cached callback data without initializing Supabase',
    (tester) async {
      final local = UiLocal();
      await tester.pumpWidget(
        app(OfflineHomePage(local: local, onGoOnline: () {})),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('创建离线签到'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminCreateSessionPage), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('测试成员'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(AdminCreateSessionPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('测试成员'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ended local task retains editable remark before first sync', (
    tester,
  ) async {
    final local = UiLocal()..closed = true;
    await tester.pumpWidget(
      app(OfflineSessionPage(local: local, sessionId: 'session')),
    );
    await tester.pumpAndSettle();
    expect(find.text('签到'), findsNothing);
    await tester.ensureVisible(find.text('编辑备注'));
    await tester.tap(find.text('编辑备注'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '请输入备注，可留空'), '测试备注');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(local.remark, '测试备注');
    expect(tester.takeException(), isNull);
  });

  testWidgets('locked snapshot blocks remark editing and signing in', (
    tester,
  ) async {
    final local = UiLocal()
      ..closed = true
      ..locked = true;
    await tester.pumpWidget(
      app(OfflineSessionPage(local: local, sessionId: 'session')),
    );
    await tester.pumpAndSettle();
    expect(find.text('签到'), findsNothing);
    await tester.ensureVisible(find.text('编辑备注'));
    await tester.tap(find.text('编辑备注'));
    await tester.pumpAndSettle();
    expect(find.text('同步快照已锁定，本机记录只读。'), findsOneWidget);
    expect(find.text('请输入备注，可留空'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
