import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/admin_session.dart';
import '../models/group.dart';
import '../models/member.dart';
import '../models/offline_session.dart';
import '../models/session_member.dart';
import '../utils/name_sorter.dart';
import 'offline_store.dart';
import 'time_service.dart';

class OfflineRoster {
  const OfflineRoster({
    required this.ownerId,
    required this.savedAt,
    required this.groups,
    required this.members,
  });
  final String ownerId;
  final DateTime savedAt;
  final List<TeamGroup> groups;
  final List<TeamMember> members;
}

class OfflineAttendanceService {
  OfflineAttendanceService({
    required this.store,
    required this.scope,
    DateTime Function()? clock,
    String Function()? newId,
  }) : _clock = clock ?? DateTime.now,
       _newId = newId ?? const Uuid().v4;

  final OfflineStore store;
  final String scope;
  final DateTime Function() _clock;
  final String Function() _newId;

  String _iso(DateTime time) => time.toUtc().toIso8601String();

  Future<bool> getOfflineMode() async {
    final db = await store.database;
    final rows = await db.query(
      'offline_settings',
      where: 'key = ?',
      whereArgs: ['mode:$scope'],
    );
    return rows.isNotEmpty && rows.first['value'] == 'offline';
  }

  Future<void> setOfflineMode(bool offline) async {
    final db = await store.database;
    await db.insert('offline_settings', {
      'key': 'mode:$scope',
      'value': offline ? 'offline' : 'online',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveRoster({
    required String ownerId,
    required List<TeamGroup> groups,
    required List<TeamMember> members,
  }) async {
    if (ownerId.isEmpty) throw StateError('请先登录管理员帐号。');
    final db = await store.database;
    await db.insert('offline_roster', {
      'scope': scope,
      'owner_id': ownerId,
      'saved_at': _iso(_clock()),
      'groups_json': jsonEncode(
        groups
            .map(
              (g) => {
                'id': g.id,
                'name': g.name,
                'description': g.description,
                'created_at': g.createdAt == null ? null : _iso(g.createdAt!),
              },
            )
            .toList(),
      ),
      'members_json': jsonEncode(
        members
            .where((m) => m.isActive)
            .map(
              (m) => {
                'id': m.id,
                'name': m.name,
                'student_id': m.studentId,
                'gender': m.gender,
                'group_id': m.groupId,
                'is_active': m.isActive,
                'created_at': _iso(m.createdAt),
                'groups': {'name': m.groupName},
              },
            )
            .toList(),
      ),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<OfflineRoster?> getRoster() async {
    final db = await store.database;
    final rows = await db.query(
      'offline_roster',
      where: 'scope = ?',
      whereArgs: [scope],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return OfflineRoster(
      ownerId: row['owner_id'] as String,
      savedAt: DateTime.parse(row['saved_at'] as String).toLocal(),
      groups: (jsonDecode(row['groups_json'] as String) as List)
          .map((g) => TeamGroup.fromJson(Map<String, dynamic>.from(g)))
          .toList(),
      members: sortMembersByName(
        (jsonDecode(row['members_json'] as String) as List)
            .map((m) => TeamMember.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      ),
    );
  }

  List<TeamMember> sortMembersByName(List<TeamMember> members) =>
      members..sort((a, b) => compareNamesByPinyin(a.name, b.name));

  Future<String> createSession(CreateSessionInput input) async {
    final roster = await getRoster();
    if (roster == null || roster.members.isEmpty) {
      throw StateError('请先在在线模式中准备离线名单。');
    }
    if (input.title.trim().isEmpty ||
        !input.endTime.isAfter(input.requiredTime) ||
        input.memberIds.isEmpty) {
      throw ArgumentError('标题、签到时间和参与成员不完整。');
    }
    if (input.memberIds.toSet().length != input.memberIds.length) {
      throw ArgumentError('参与成员重复。');
    }
    final byId = {for (final m in roster.members) m.id: m};
    if (input.memberIds.any((id) => !byId.containsKey(id))) {
      throw StateError('所选成员不在本机名单内，请重新准备名单。');
    }
    final id = _newId();
    final db = await store.database;
    await db.transaction((txn) async {
      await txn.insert('offline_sessions', {
        'id': id,
        'scope': scope,
        'owner_id': roster.ownerId,
        'title': input.title.trim(),
        'required_time': _iso(input.requiredTime),
        'end_time': _iso(input.endTime),
        'status': 'active',
        'created_at': _iso(_clock()),
      });
      for (final memberId in input.memberIds) {
        final m = byId[memberId]!;
        await txn.insert('offline_session_members', {
          'id': _newId(),
          'session_id': id,
          'member_id': memberId,
          'member_json': jsonEncode({
            'name': m.name,
            'student_id': m.studentId,
            'gender': m.gender,
            'groups': {'name': m.groupName},
          }),
        });
      }
    });
    return id;
  }

  Future<Map<String, Object?>> _sessionRow(
    DatabaseExecutor db,
    String id,
  ) async {
    final rows = await db.query(
      'offline_sessions',
      where: 'id = ? AND scope = ?',
      whereArgs: [id, scope],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('本机离线任务不存在。');
    return rows.first;
  }

  Future<OfflineSession> getSession(String id) async {
    final db = await store.database;
    return OfflineSession.fromRow(await _sessionRow(db, id));
  }

  Future<List<OfflineSession>> listSessions() async {
    final db = await store.database;
    final rows = await db.query(
      'offline_sessions',
      where: 'scope = ?',
      whereArgs: [scope],
      orderBy: 'created_at DESC, id',
    );
    return rows.map(OfflineSession.fromRow).toList();
  }

  Future<List<SessionMember>> getMembers(String sessionId) async {
    final db = await store.database;
    await _sessionRow(db, sessionId);
    final rows = await db.query(
      'offline_session_members',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'id',
    );
    return sortMembersByPinyin(
      rows
          .map(
            (r) => SessionMember.fromJson({
              ...r,
              'members': jsonDecode(r['member_json'] as String),
            }),
          )
          .toList(),
    );
  }

  Future<SessionMember> checkin(String sessionId, String recordId) async {
    final db = await store.database;
    await db.transaction((txn) async {
      final s = OfflineSession.fromRow(await _sessionRow(txn, sessionId));
      final now = _clock();
      if (!s.canEdit || s.isClosed) throw StateError('任务已结束或已锁定。');
      final preview = TimeService().previewCheckin(
        now: now,
        requiredTime: s.session.requiredTime,
        endTime: s.session.endTime,
      );
      if (!preview.canCheckin) throw StateError('签到已结束，请刷新任务。');
      final count = await txn.update(
        'offline_session_members',
        {
          'status': preview.status,
          'checkin_time': _iso(now),
          'late_minutes': preview.lateMinutes,
        },
        where: 'id = ? AND session_id = ? AND status = ?',
        whereArgs: [recordId, sessionId, 'pending'],
      );
      if (count != 1) throw StateError('该成员已签到或记录状态已变化。');
    });
    return (await getMembers(sessionId)).firstWhere((m) => m.id == recordId);
  }

  Future<void> saveRemark(
    String sessionId,
    String recordId,
    String remark,
  ) async {
    final db = await store.database;
    await db.transaction((txn) async {
      final s = OfflineSession.fromRow(await _sessionRow(txn, sessionId));
      if (!s.canEdit) throw StateError('同步快照已锁定，不能修改本机备注。');
      final count = await txn.update(
        'offline_session_members',
        {'remark': remark.trim().isEmpty ? null : remark.trim()},
        where: 'id = ? AND session_id = ?',
        whereArgs: [recordId, sessionId],
      );
      if (count != 1) throw StateError('成员记录不存在。');
    });
  }

  Future<void> closeSession(String id, {bool onlyIfExpired = false}) async {
    final db = await store.database;
    await db.transaction((txn) async {
      final s = OfflineSession.fromRow(await _sessionRow(txn, id));
      if (s.isClosed || s.locked) return;
      final now = _clock();
      if (onlyIfExpired && !now.isAfter(s.session.endTime)) return;
      await txn.update(
        'offline_session_members',
        {'status': 'absent'},
        where: 'session_id = ? AND status = ?',
        whereArgs: [id, 'pending'],
      );
      await txn.update(
        'offline_sessions',
        {'status': 'closed', 'closed_at': _iso(now)},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  /// Freeze exactly one final snapshot, before making any network request.
  Future<Map<String, dynamic>> prepareUpload(String id, String ownerId) async {
    final db = await store.database;
    return db.transaction((txn) async {
      final row = await _sessionRow(txn, id);
      final s = OfflineSession.fromRow(row);
      if (!s.isClosed) throw StateError('请先结束任务，再手动同步。');
      if (s.ownerId != ownerId) throw StateError('请使用准备名单时的帐号同步。');
      if (s.isSynced) throw StateError('该任务已经同步。');
      final records = await txn.query(
        'offline_session_members',
        where: 'session_id = ?',
        whereArgs: [id],
        orderBy: 'id',
      );
      if (records.isEmpty || records.any((r) => r['status'] == 'pending')) {
        throw StateError('任务结束数据不完整，暂不能同步。');
      }
      await txn.update(
        'offline_sessions',
        {'locked': 1, 'sync_state': 'syncing', 'last_error': null},
        where: 'id = ?',
        whereArgs: [id],
      );
      return {
        'version': 1,
        'session': {
          'id': id,
          'title': row['title'],
          'required_time': row['required_time'],
          'end_time': row['end_time'],
          'created_at': row['created_at'],
          'closed_at': row['closed_at'],
          'status': 'closed',
        },
        'members': records
            .map(
              (r) => {
                'id': r['id'],
                'member_id': r['member_id'],
                'status': r['status'],
                'checkin_time': r['checkin_time'],
                'late_minutes': r['late_minutes'],
                'remark': r['remark'],
              },
            )
            .toList(),
      };
    });
  }

  Future<void> finishUpload(String id, {String? error}) async {
    final db = await store.database;
    await _sessionRow(db, id);
    await db.update(
      'offline_sessions',
      {
        'sync_state': error == null ? 'synced' : 'failed',
        'last_error': error,
        'locked': 1,
      },
      where: 'id = ? AND locked = 1',
      whereArgs: [id],
    );
  }
}
