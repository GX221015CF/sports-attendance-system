import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/session_member.dart';
import 'package:mobile_app/widgets/attendance_motion.dart';
import 'package:mobile_app/widgets/error_state.dart';
import 'package:mobile_app/widgets/member_card.dart';

import 'attendance_workspace_test.dart' as fixture;

class SaveProbe {
  int calls = 0;
  bool fail = false;
  Completer<void>? pending;
  final Map<String, SessionMember> saved = {};
  List<SessionMember> roster() =>
      fixture.signingRoster(count: 8).map((m) => saved[m.id] ?? m).toList();
  Future<SessionMember> save(String id) async {
    calls++;
    await pending?.future;
    if (fail) throw StateError('synthetic write failure');
    final member = roster().firstWhere((m) => m.id == id);
    return saved[id] = member.recordedCheckin(
      status: 'normal',
      time: DateTime.now(),
      lateMinutes: 0,
    );
  }
}

class MotionCloud extends fixture.SigningCloud {
  MotionCloud(this.probe);
  final SaveProbe probe;
  Completer<List<SessionMember>>? loading;
  @override
  Future<List<SessionMember>> getSessionMembers(String sessionId) async =>
      loading == null ? probe.roster() : loading!.future;
  @override
  Future<void> checkinMember({
    required String sessionMemberId,
    required String status,
    required DateTime checkinTime,
    required int lateMinutes,
  }) async {
    await probe.save(sessionMemberId);
  }
}

class MotionLocal extends fixture.SigningLocal {
  MotionLocal(this.probe);
  final SaveProbe probe;
  @override
  Future<List<SessionMember>> getMembers(String id) async => probe.roster();
  @override
  Future<SessionMember> checkin(String sessionId, String recordId) =>
      probe.save(recordId);
}

Widget motionApp(Widget child, {bool reduced = false}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
    child: child!,
  ),
  home: child,
);

void main() {
  for (final local in [false, true]) {
    final mode = local ? 'offline' : 'online';
    Widget page(SaveProbe probe) => fixture.signingPage(
      local,
      cloud: MotionCloud(probe),
      device: MotionLocal(probe),
    );

    testWidgets(
      '$mode waits for persistence and rejects repeated or stale taps',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1180, 820));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final probe = SaveProbe()..pending = Completer<void>();
        await tester.pumpWidget(motionApp(page(probe)));
        await tester.pumpAndSettle();
        final oldTap = tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, '签到').first,
            )
            .onPressed!;
        oldTap();
        oldTap();
        await tester.pump();
        expect(probe.calls, 1);
        expect(find.byType(Dialog), findsNothing);
        expect(find.text('保存中'), findsOneWidget);
        expect(
          tester.widget<CheckinFeedback>(find.byType(CheckinFeedback)).sequence,
          0,
        );
        probe.pending!.complete();
        await tester.pumpAndSettle();
        expect(
          tester.widget<CheckinFeedback>(find.byType(CheckinFeedback)).sequence,
          1,
        );
        final first = tester
            .widgetList<MemberCard>(find.byType(MemberCard))
            .firstWhere((m) => m.member.id == 'record-0');
        expect(first.member.status, 'normal');
        expect(first.member.checkinTime, isNotNull);
        oldTap();
        await tester.pump();
        expect(probe.calls, 1);
        await tester.pump(const Duration(seconds: 2));
        expect(find.textContaining('签到成功'), findsNothing);
        expect(
          tester.widget<CheckinFeedback>(find.byType(CheckinFeedback)).sequence,
          1,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$mode failed save never celebrates and can retry', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1180, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final probe = SaveProbe()..fail = true;
      await tester.pumpWidget(motionApp(page(probe)));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '签到').first);
      await tester.pumpAndSettle();
      expect(probe.calls, 1);
      expect(
        tester.widget<CheckinFeedback>(find.byType(CheckinFeedback)).sequence,
        0,
      );
      expect(probe.saved, isEmpty);
      probe.fail = false;
      await tester.tap(find.widgetWithText(ElevatedButton, '签到').first);
      await tester.pumpAndSettle();
      expect(probe.calls, 2);
      expect(
        tester.widget<CheckinFeedback>(find.byType(CheckinFeedback)).sequence,
        1,
      );
      expect(probe.saved.length, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$mode leaving while saving does not replay feedback', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1180, 820));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final probe = SaveProbe()..pending = Completer<void>();
      await tester.pumpWidget(motionApp(page(probe)));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, '签到').first);
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      probe.pending!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [
    const Size(420, 900),
    const Size(800, 360),
    const Size(1180, 820),
  ]) {
    testWidgets('skeleton lands into data at $size without a minimum wait', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cloud = MotionCloud(SaveProbe())
        ..loading = Completer<List<SessionMember>>();
      await tester.pumpWidget(
        motionApp(fixture.signingPage(false, cloud: cloud)),
      );
      await tester.pump();
      expect(find.byType(LoadingSkeleton), findsOneWidget);
      expect(tester.takeException(), isNull);
      cloud.loading!.complete(fixture.signingRoster(count: 4));
      await tester.pumpAndSettle();
      expect(find.byType(LoadingSkeleton), findsNothing);
      expect(find.byType(MemberCard), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('loading failure clears skeleton and exposes retry', (
    tester,
  ) async {
    final cloud = MotionCloud(SaveProbe())
      ..loading = Completer<List<SessionMember>>();
    await tester.pumpWidget(
      motionApp(fixture.signingPage(false, cloud: cloud)),
    );
    await tester.pump();
    cloud.loading!.completeError(StateError('synthetic read failure'));
    await tester.pumpAndSettle();
    expect(find.byType(LoadingSkeleton), findsNothing);
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('reduced motion leaves skeleton and success static', (
    tester,
  ) async {
    await tester.pumpWidget(
      motionApp(
        const Scaffold(body: LoadingSkeleton(fullPage: true)),
        reduced: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(
      motionApp(
        const Scaffold(
          body: CheckinFeedback(
            sequence: 0,
            message: null,
            child: SizedBox.expand(),
          ),
        ),
        reduced: true,
      ),
    );
    await tester.pumpWidget(
      motionApp(
        const Scaffold(
          body: CheckinFeedback(
            sequence: 1,
            message: '签到成功',
            child: SizedBox.expand(),
          ),
        ),
        reduced: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('签到成功'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('签到成功'), findsNothing);
  });

  testWidgets(
    'count rolls only when value changes and reduces to static text',
    (tester) async {
      await tester.pumpWidget(
        motionApp(const Scaffold(body: RollingCount(value: 9))),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        motionApp(const Scaffold(body: RollingCount(value: 10))),
      );
      await tester.pump();
      expect(find.text('10'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('9'), findsNothing);
      await tester.pumpWidget(
        motionApp(const Scaffold(body: RollingCount(value: 11)), reduced: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('11'), findsOneWidget);
      expect(find.byType(AnimatedSwitcher), findsNothing);
    },
  );
}
