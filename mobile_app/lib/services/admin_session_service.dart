import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_session.dart';
import '../models/group.dart';
import '../models/member.dart';
import '../models/session_member.dart';
import '../utils/name_sorter.dart';

class AdminSessionService {
  AdminSessionService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<AdminSession>> fetchSessionsWithStats() async {
    final sessionRows = await _client
        .from('attendance_sessions')
        .select('id, title, required_time, end_time, status, created_at')
        .order('created_at', ascending: false);

    final memberRows = await _client
        .from('session_members')
        .select('session_id, status');

    final statsBySessionId = <String, _MutableSessionStats>{};

    for (final row in memberRows) {
      final sessionId = row['session_id'] as String?;
      if (sessionId == null) {
        continue;
      }

      final stats = statsBySessionId.putIfAbsent(
        sessionId,
        _MutableSessionStats.new,
      );
      stats.add(row['status'] as String? ?? 'pending');
    }

    return sessionRows.map((row) {
      final sessionId = row['id'] as String;
      return AdminSession.fromJson(
        row,
        statsBySessionId[sessionId]?.toStats() ?? SessionStats.empty(),
      );
    }).toList();
  }

  Future<List<TeamGroup>> fetchGroups() async {
    final rows = await _client
        .from('groups')
        .select('id, name, description')
        .order('name', ascending: true);

    return rows.map(TeamGroup.fromJson).toList();
  }

  Future<List<TeamMember>> fetchActiveMembers() async {
    final rows = await _client
        .from('members')
        .select(
          'id, name, student_id, gender, phone, group_id, is_active, '
          'created_at, groups(name)',
        )
        .eq('is_active', true);

    final members = rows.map(TeamMember.fromJson).toList();
    members.sort((a, b) => compareNamesByPinyin(a.name, b.name));
    return members;
  }

  Future<AdminSession> fetchSessionDetail(String sessionId) async {
    final sessionRows = await _client
        .from('attendance_sessions')
        .select('id, title, required_time, end_time, status, created_at')
        .eq('id', sessionId)
        .limit(1);

    if (sessionRows.isEmpty) {
      throw StateError('签到任务不存在或已被删除。');
    }

    final memberRows = await _client
        .from('session_members')
        .select('status')
        .eq('session_id', sessionId);

    final stats = _MutableSessionStats();
    for (final row in memberRows) {
      stats.add(row['status'] as String? ?? 'pending');
    }

    return AdminSession.fromJson(sessionRows.first, stats.toStats());
  }

  Future<List<SessionMember>> fetchSessionMembers(String sessionId) async {
    final rows = await _client
        .from('session_members')
        .select(
          'id, session_id, member_id, status, checkin_time, late_minutes, remark, '
          'created_at, members(name, student_id, gender, phone, groups(name))',
        )
        .eq('session_id', sessionId)
        .order('created_at', ascending: true);

    final members = rows.map(SessionMember.fromJson).toList();
    return sortMembersByPinyin(members);
  }

  Future<String> createSession(CreateSessionInput input) async {
    final sessionRows = await _client
        .from('attendance_sessions')
        .insert({
          'title': input.title,
          'required_time': input.requiredTime.toUtc().toIso8601String(),
          'end_time': input.endTime.toUtc().toIso8601String(),
          'status': 'active',
        })
        .select('id');

    if (sessionRows.isEmpty) {
      throw StateError('签到任务创建失败，请稍后重试。');
    }

    final sessionId = sessionRows.first['id'] as String;

    await _client
        .from('session_members')
        .insert(
          input.memberIds
              .map(
                (memberId) => {
                  'session_id': sessionId,
                  'member_id': memberId,
                  'status': 'pending',
                  'late_minutes': 0,
                },
              )
              .toList(),
        );

    return sessionId;
  }

  Future<void> closeSession(String sessionId) async {
    await _client
        .from('session_members')
        .update({'status': 'absent'})
        .eq('session_id', sessionId)
        .eq('status', 'pending');

    await _client
        .from('attendance_sessions')
        .update({'status': 'closed'})
        .eq('id', sessionId)
        .eq('status', 'active');
  }

  Future<void> updateSessionMemberRemark({
    required String sessionMemberId,
    required String remark,
  }) async {
    final trimmedRemark = remark.trim();
    await _client
        .from('session_members')
        .update({'remark': trimmedRemark.isEmpty ? null : trimmedRemark})
        .eq('id', sessionMemberId);
  }
}

class _MutableSessionStats {
  int total = 0;
  int normal = 0;
  int late = 0;
  int absent = 0;
  int pending = 0;

  void add(String status) {
    total++;

    switch (status) {
      case 'normal':
        normal++;
      case 'late':
        late++;
      case 'absent':
        absent++;
      default:
        pending++;
    }
  }

  SessionStats toStats() {
    return SessionStats(
      total: total,
      normal: normal,
      late: late,
      absent: absent,
      pending: pending,
    );
  }
}
