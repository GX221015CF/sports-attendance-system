import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/admin_session.dart';
import 'package:mobile_app/models/attendance_session.dart';
import 'package:mobile_app/models/group.dart';
import 'package:mobile_app/models/member.dart';
import 'package:mobile_app/models/offline_session.dart';
import 'package:mobile_app/models/session_member.dart';
import 'package:mobile_app/pages/current_session_page.dart';
import 'package:mobile_app/pages/offline_home_page.dart';
import 'package:mobile_app/pages/admin/admin_home_page.dart';
import 'package:mobile_app/pages/admin/admin_members_page.dart';
import 'package:mobile_app/pages/admin/admin_groups_page.dart';
import 'package:mobile_app/pages/admin/admin_sessions_page.dart';
import 'package:mobile_app/pages/admin/admin_session_detail_page.dart';
import 'package:mobile_app/services/admin_auth_service.dart';
import 'package:mobile_app/services/admin_dashboard_service.dart';
import 'package:mobile_app/services/admin_member_service.dart';
import 'package:mobile_app/services/admin_group_service.dart';
import 'package:mobile_app/services/admin_session_service.dart';
import 'package:mobile_app/widgets/admin/admin_member_card.dart';
import 'package:mobile_app/widgets/admin/admin_group_card.dart';

import 'attendance_workspace_test.dart' as signing;
import 'interaction_layout_test.dart' as creation;
import 'offline_ui_test.dart' show UiLocal;

class HomeCloud extends signing.SigningCloud {
  @override
  Future<AttendanceSession?> getCurrentActiveSession() async =>
      signing.signingSession();
  @override
  Future<Map<String, int>> getSessionStats(String sessionId) async => {
    'total': 500,
    'checked': 250,
    'pending': 125,
    'normal': 125,
    'late': 125,
    'absent': 125,
  };
}

class DashboardFixture implements AdminDashboardService {
  bool fail = false;
  @override
  Future<AdminDashboardStats> fetchDashboardStats() async {
    if (fail) throw StateError('synthetic failure');
    return const AdminDashboardStats(
      activeMembers: 500,
      groups: 20,
      activeSessions: 2,
      closedSessions: 80,
      pendingCheckins: 111,
      lateCheckins: 222,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class AuthFixture implements AdminAuthService {
  @override
  get currentUser => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MembersFixture implements AdminMemberService {
  @override
  Future<List<TeamMember>> fetchMembers() async => creation.roster(500);
  @override
  Future<List<TeamGroup>> fetchGroups() async => const [
    TeamGroup(id: 'fixture-group', name: '合成测试组'),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class GroupsFixture implements AdminGroupService {
  @override
  Future<List<AdminGroupSummary>> fetchGroupsWithMemberCount() async =>
      List.generate(
        500,
        (index) => AdminGroupSummary(
          group: TeamGroup(
            id: 'group-$index',
            name: '合成分组${index.toString().padLeft(3, '0')}',
            description: '用于布局检查的合成分组说明',
          ),
          memberCount: 10,
        ),
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AdminSession adminSession(int index) => AdminSession(
  id: 'session-$index',
  title: '合成任务${index.toString().padLeft(3, '0')}',
  requiredTime: DateTime(2026, 10, 24, 18),
  endTime: DateTime(2026, 10, 24, 19),
  createdAt: DateTime(2026, 10, 24),
  status: 'active',
  stats: const SessionStats(
    total: 500,
    normal: 125,
    late: 125,
    absent: 125,
    pending: 125,
  ),
);

class SessionsFixture implements AdminSessionService {
  @override
  Future<List<AdminSession>> fetchSessionsWithStats() async =>
      List.generate(500, adminSession);
  @override
  Future<AdminSession> fetchSessionDetail(String sessionId) async =>
      adminSession(0);
  @override
  Future<List<SessionMember>> fetchSessionMembers(String sessionId) async =>
      signing.signingRoster();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class HomeLocal extends UiLocal {
  @override
  Future<List<OfflineSession>> listSessions() async => List.generate(
    500,
    (index) => OfflineSession(
      session: AttendanceSession(
        id: 'local-$index',
        title: '离线任务${index.toString().padLeft(3, '0')}',
        requiredTime: time.add(const Duration(hours: 1)),
        endTime: time.add(const Duration(hours: 2)),
        status: 'active',
        createdAt: time,
      ),
      ownerId: 'fixture-owner',
      syncState: 'local',
      locked: false,
    ),
  );
}

Widget homeAdminPage(String name) => switch (name) {
  'online' => CurrentSessionPage(attendanceService: HomeCloud()),
  'offline' => OfflineHomePage(local: HomeLocal(), onGoOnline: () {}),
  'dashboard' => AdminHomePage(
    dashboardService: DashboardFixture(),
    authService: AuthFixture(),
  ),
  'members' => AdminMembersPage(memberService: MembersFixture()),
  'groups' => AdminGroupsPage(groupService: GroupsFixture()),
  'sessions' => AdminSessionsPage(sessionService: SessionsFixture()),
  _ => AdminSessionDetailPage(
    sessionId: 'session-0',
    sessionService: SessionsFixture(),
  ),
};

const firstItems = {
  'online': '进入签到',
  'offline': '离线任务000',
  'dashboard': '成员总数',
  'members': '合成成员000',
  'groups': '合成分组000',
  'sessions': '合成任务000',
  'detail': '合成成员000',
};

void main() {
  for (final entry in firstItems.entries) {
    for (final size in [const Size(1180, 820), const Size(800, 360)]) {
      testWidgets('${entry.key} at $size exposes first work item', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(signing.signingApp(homeAdminPage(entry.key)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(entry.value).first.hitTestable(), findsOneWidget);
        if (entry.key == 'dashboard') {
          for (final removed in ['待签到人数', '迟到人数']) {
            expect(find.text(removed), findsNothing);
          }
          for (final label in ['成员总数', '分组数量', '进行中签到', '已结束签到']) {
            expect(find.text(label), findsOneWidget);
          }
          expect(find.text('创建签到').hitTestable(), findsOneWidget);
        }
        if (entry.key == 'members') {
          expect(find.byType(AdminMemberCard).evaluate().length, lessThan(30));
        }
        if (entry.key == 'groups') {
          expect(find.byType(AdminGroupCard).evaluate().length, lessThan(30));
        }
        if (entry.key == 'sessions') {
          expect(find.text('查看详情').evaluate().length, lessThan(30));
        }
        if (entry.key == 'detail') {
          expect(find.text('编辑备注').evaluate().length, lessThan(30));
        }
        if (entry.key == 'offline') {
          expect(find.text('手动同步'), findsNothing);
          expect(find.text('进入签到').evaluate().length, lessThan(30));
        }
      });
    }
    testWidgets('${entry.key} large text has no layout overflow', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1180, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        signing.signingApp(homeAdminPage(entry.key), scale: 1.6),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  for (final name in ['members', 'groups', 'sessions', 'detail']) {
    testWidgets(
      '$name keeps tablet search through keyboard resize and rotation',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1180, 820);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(signing.signingApp(homeAdminPage(name)));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '合成');
        await tester.pump(const Duration(milliseconds: 200));
        tester.view.viewInsets = const FakeViewPadding(bottom: 520);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(TextField).hitTestable(), findsOneWidget);
        tester.view.viewInsets = FakeViewPadding.zero;
        tester.view.physicalSize = const Size(420, 900);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '合成',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'members scrolling keeps filters visible and search recovers a distant member',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1180, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(signing.signingApp(homeAdminPage('members')));
      await tester.pumpAndSettle();
      final scrollable = find.descendant(
        of: find.byKey(const PageStorageKey('admin-members-content')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('合成成员080'),
        400,
        scrollable: scrollable,
      );
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      expect(find.text('队员资料库').hitTestable(), findsOneWidget);
      await tester.enterText(find.byType(TextField), '合成成员080');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AdminMemberCard),
          matching: find.text('合成成员080'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dashboard failure preserves create and management entries', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      signing.signingApp(
        AdminHomePage(
          dashboardService: DashboardFixture()..fail = true,
          authService: AuthFixture(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('数据看板加载失败'), findsOneWidget);
    expect(find.text('创建签到').hitTestable(), findsOneWidget);
    await tester.ensureVisible(find.text('成员管理'));
    expect(find.text('成员管理').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
