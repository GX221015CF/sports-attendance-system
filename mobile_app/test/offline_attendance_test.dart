import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/admin_session.dart';
import 'package:mobile_app/models/group.dart';
import 'package:mobile_app/models/member.dart';
import 'package:mobile_app/services/offline_attendance_service.dart';
import 'package:mobile_app/services/offline_store.dart';
import 'package:mobile_app/services/offline_sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

const owner = '11111111-1111-4111-8111-111111111111';
final requiredTime = DateTime.utc(2026, 10, 10, 10);
final endTime = requiredTime.add(const Duration(hours: 1));

class FakeUploader implements OfflineUploader {
  int calls = 0;
  bool fail = false;
  bool loseFirstResponse = false;
  final Set<String> committed = {};
  Completer<void>? gate;
  Map<String, dynamic>? payload;
  @override
  Future<String> upload(Map<String, dynamic> value) async {
    calls++;
    payload = value;
    if (gate != null) await gate!.future;
    if (fail) throw const SocketException('offline');
    final id = value['session']['id'] as String;
    committed.add(id);
    if (loseFirstResponse && calls == 1) {
      throw TimeoutException('response lost');
    }
    return id;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late OfflineStore store;
  late OfflineAttendanceService local;
  late DateTime now;
  late String path;

  Future<void> seed() => local.saveRoster(
    ownerId: owner,
    groups: const [TeamGroup(id: 'group', name: '测试组')],
    members: List.generate(
      3,
      (i) => TeamMember(
        id: '22222222-2222-4222-8222-22222222222$i',
        name: '测试成员$i',
        isActive: true,
        createdAt: requiredTime,
        groupId: 'group',
        groupName: '测试组',
        studentId: 'TEST$i',
      ),
    ),
  );

  Future<String> create() async => local.createSession(
    CreateSessionInput(
      title: '离线测试',
      requiredTime: requiredTime,
      endTime: endTime,
      memberIds: (await local.getRoster())!.members.map((m) => m.id).toList(),
    ),
  );

  setUp(() async {
    final dir = Directory('.dart_tool/offline-tests');
    await dir.create(recursive: true);
    path = '${dir.absolute.path}/${const Uuid().v4()}.db';
    store = OfflineStore(factory: databaseFactoryFfi, path: path);
    now = requiredTime;
    local = OfflineAttendanceService(
      store: store,
      scope: 'test',
      clock: () => now,
    );
    await seed();
  });
  tearDown(() => store.close());

  test('missing roster cannot publish a local task', () async {
    final other = OfflineAttendanceService(store: store, scope: 'other');
    await expectLater(
      other.createSession(
        CreateSessionInput(
          title: '无名单',
          requiredTime: requiredTime,
          endTime: endTime,
          memberIds: ['x'],
        ),
      ),
      throwsStateError,
    );
    expect(await other.listSessions(), isEmpty);
  });

  test('publishing snapshots members and does not write the cloud', () async {
    final uploader = FakeUploader();
    final id = await create();
    expect((await local.getMembers(id)).length, 3);
    expect((await local.getSession(id)).session.status, 'active');
    await local.setOfflineMode(true);
    await local.listSessions();
    await local.setOfflineMode(false);
    expect(uploader.calls, 0);
  });

  test(
    'duplicate or unknown participants do not create partial tasks',
    () async {
      final roster = (await local.getRoster())!;
      await expectLater(
        local.createSession(
          CreateSessionInput(
            title: '重复',
            requiredTime: requiredTime,
            endTime: endTime,
            memberIds: [roster.members.first.id, roster.members.first.id],
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(
        local.createSession(
          CreateSessionInput(
            title: '未知',
            requiredTime: requiredTime,
            endTime: endTime,
            memberIds: ['x'],
          ),
        ),
        throwsStateError,
      );
      expect(await local.listSessions(), isEmpty);
    },
  );

  test(
    'check-in at required time is normal; late minimum is one minute',
    () async {
      final id = await create();
      final members = await local.getMembers(id);
      final normal = await local.checkin(id, members[0].id);
      now = requiredTime.add(const Duration(seconds: 30));
      final late = await local.checkin(id, members[1].id);
      expect(normal.status, 'normal');
      expect(normal.lateMinutes, 0);
      expect(late.status, 'late');
      expect(late.lateMinutes, 1);
    },
  );

  test(
    'end boundary is allowed; after end rejected and locally closed on refresh',
    () async {
      final id = await create();
      final members = await local.getMembers(id);
      now = endTime;
      expect((await local.checkin(id, members[0].id)).status, 'late');
      now = endTime.add(const Duration(seconds: 1));
      await expectLater(local.checkin(id, members[1].id), throwsStateError);
      await local.closeSession(id, onlyIfExpired: true);
      final results = await local.getMembers(id);
      expect(results[0].status, 'late');
      expect(results[1].status, 'absent');
      expect((await local.getSession(id)).isClosed, isTrue);
    },
  );

  test('repeated check-in cannot overwrite time or result', () async {
    final id = await create();
    final m = (await local.getMembers(id)).first;
    final first = await local.checkin(id, m.id);
    now = requiredTime.add(const Duration(minutes: 10));
    await expectLater(local.checkin(id, m.id), throwsStateError);
    final current = (await local.getMembers(id)).first;
    expect(current.checkinTime, first.checkinTime);
    expect(current.status, 'normal');
  });

  test(
    'remark is isolated; can be cleared and changed after local close',
    () async {
      final id = await create();
      final m = (await local.getMembers(id)).first;
      await local.checkin(id, m.id);
      await local.saveRemark(id, m.id, '  测试备注  ');
      final saved = (await local.getMembers(id)).first;
      expect(saved.remark, '测试备注');
      expect(saved.status, 'normal');
      expect(saved.checkinTime!.toUtc(), now);
      await local.closeSession(id);
      await local.saveRemark(id, m.id, '');
      expect((await local.getMembers(id)).first.remark, '');
    },
  );

  test('manual early end marks only pending members absent', () async {
    final id = await create();
    final members = await local.getMembers(id);
    await local.checkin(id, members.first.id);
    await local.closeSession(id);
    final result = await local.getMembers(id);
    expect(result.where((m) => m.status == 'normal').length, 1);
    expect(result.where((m) => m.status == 'absent').length, 2);
    await expectLater(local.checkin(id, members[1].id), throwsStateError);
  });

  test('only expired tasks are automatically closed locally', () async {
    final id = await create();
    await local.closeSession(id, onlyIfExpired: true);
    expect((await local.getSession(id)).isClosed, isFalse);
    now = endTime.add(const Duration(seconds: 1));
    await local.closeSession(id, onlyIfExpired: true);
    expect((await local.getSession(id)).isClosed, isTrue);
  });

  test('refreshing roster cannot change the published task snapshot', () async {
    final id = await create();
    await local.saveRoster(ownerId: owner, groups: [], members: []);
    expect((await local.getRoster())!.members, isEmpty);
    expect((await local.getMembers(id)).length, 3);
  });

  test('active tasks cannot sync, even if network is available', () async {
    final uploader = FakeUploader();
    final sync = OfflineSyncService(local, uploader);
    final id = await create();
    await expectLater(sync.sync(id, ownerId: owner), throwsStateError);
    expect(uploader.calls, 0);
    expect((await local.getSession(id)).locked, isFalse);
  });

  test('wrong account rejected before upload and snapshot lock', () async {
    final id = await create();
    await local.closeSession(id);
    final uploader = FakeUploader();
    await expectLater(
      OfflineSyncService(local, uploader).sync(id, ownerId: 'different'),
      throwsStateError,
    );
    expect(uploader.calls, 0);
    expect((await local.getSession(id)).locked, isFalse);
  });

  test(
    'complete manual sync sends original times; subsequent sync is a no-op',
    () async {
      final id = await create();
      final m = (await local.getMembers(id)).first;
      await local.checkin(id, m.id);
      await local.closeSession(id);
      now = endTime.add(const Duration(days: 1));
      final uploader = FakeUploader();
      final sync = OfflineSyncService(local, uploader);
      await sync.sync(id, ownerId: owner);
      final rows = uploader.payload!['members'] as List;
      expect(
        rows.singleWhere((r) => r['id'] == m.id)['checkin_time'],
        requiredTime.toIso8601String(),
      );
      expect((await local.getSession(id)).isSynced, isTrue);
      await sync.sync(id, ownerId: owner);
      expect(uploader.calls, 1);
    },
  );

  test(
    'failed sync preserves all data and allows only explicit retry',
    () async {
      final id = await create();
      await local.closeSession(id);
      final uploader = FakeUploader()..fail = true;
      final sync = OfflineSyncService(local, uploader);
      await expectLater(
        sync.sync(id, ownerId: owner),
        throwsA(isA<SocketException>()),
      );
      expect((await local.getSession(id)).syncState, 'failed');
      expect((await local.getMembers(id)).length, 3);
      await local.listSessions();
      await local.setOfflineMode(false);
      expect(uploader.calls, 1);
      uploader.fail = false;
      await sync.sync(id, ownerId: owner);
      expect(uploader.calls, 2);
      expect((await local.getSession(id)).isSynced, isTrue);
    },
  );

  test(
    'lost server response retries the exact frozen snapshot without duplicate',
    () async {
      final id = await create();
      final m = (await local.getMembers(id)).first;
      await local.closeSession(id);
      final uploader = FakeUploader()..loseFirstResponse = true;
      final sync = OfflineSyncService(local, uploader);
      await expectLater(
        sync.sync(id, ownerId: owner),
        throwsA(isA<TimeoutException>()),
      );
      await expectLater(
        local.saveRemark(id, m.id, 'changed'),
        throwsStateError,
      );
      await sync.sync(id, ownerId: owner);
      expect(uploader.committed.length, 1);
      expect((await local.getSession(id)).isSynced, isTrue);
    },
  );

  test('concurrent button calls upload only once', () async {
    final id = await create();
    await local.closeSession(id);
    final uploader = FakeUploader()..gate = Completer<void>();
    final sync = OfflineSyncService(local, uploader);
    final first = sync.sync(id, ownerId: owner);
    await expectLater(sync.sync(id, ownerId: owner), throwsStateError);
    uploader.gate!.complete();
    await first;
    expect(uploader.calls, 1);
  });

  test(
    'roster, mode, remarks and check-in survive database reopening',
    () async {
      final id = await create();
      final m = (await local.getMembers(id)).first;
      await local.checkin(id, m.id);
      await local.saveRemark(id, m.id, '重启测试');
      await local.setOfflineMode(true);
      await store.close();
      store = OfflineStore(factory: databaseFactoryFfi, path: path);
      local = OfflineAttendanceService(
        store: store,
        scope: 'test',
        clock: () => now,
      );
      expect(await local.getOfflineMode(), isTrue);
      expect((await local.getRoster())!.members.length, 3);
      final restored = (await local.getMembers(id)).first;
      expect(restored.status, 'normal');
      expect(restored.remark, '重启测试');
      expect(restored.checkinTime!.toUtc(), requiredTime);
    },
  );
}
