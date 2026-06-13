import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/attendance_session.dart';
import '../models/session_member.dart';
import '../utils/name_sorter.dart';

class AttendanceService {
  AttendanceService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<AttendanceSession?> getCurrentActiveSession() async {
    final rows = await _client
        .from('attendance_sessions')
        .select('id, title, required_time, end_time, status, created_at')
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1);

    if (rows.isEmpty) {
      return null;
    }

    return AttendanceSession.fromJson(rows.first);
  }

  Future<Map<String, int>> getSessionStats(String sessionId) async {
    final rows = await _client
        .from('session_members')
        .select('status')
        .eq('session_id', sessionId);

    final stats = <String, int>{
      'total': rows.length,
      'pending': 0,
      'normal': 0,
      'late': 0,
      'absent': 0,
      'checked': 0,
    };

    for (final row in rows) {
      final status = row['status'] as String? ?? 'pending';

      if (stats.containsKey(status)) {
        stats[status] = stats[status]! + 1;
      }

      if (status == 'normal' || status == 'late') {
        stats['checked'] = stats['checked']! + 1;
      }
    }

    return stats;
  }

  Future<List<SessionMember>> getSessionMembers(String sessionId) async {
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

  Future<void> updateSessionMemberRemark({
    required String sessionMemberId,
    required String? remark,
  }) async {
    final trimmedRemark = remark?.trim() ?? '';

    await _client
        .from('session_members')
        .update({'remark': trimmedRemark.isEmpty ? null : trimmedRemark})
        .eq('id', sessionMemberId);
  }

  Future<void> checkinMember({
    required String sessionMemberId,
    required String status,
    required DateTime checkinTime,
    required int lateMinutes,
  }) async {
    if (status != 'normal' && status != 'late') {
      throw ArgumentError('无效的签到状态：$status');
    }

    final rows = await _client
        .from('session_members')
        .update({
          'status': status,
          'checkin_time': checkinTime.toUtc().toIso8601String(),
          'late_minutes': lateMinutes,
        })
        .eq('id', sessionMemberId)
        .eq('status', 'pending')
        .select('id');

    if (rows.isEmpty) {
      throw StateError('该成员可能已经签到，或签到状态已变化，请刷新后重试。');
    }
  }

  Future<bool> closeExpiredSessionIfNeeded(AttendanceSession session) async {
    if (session.status != 'active') {
      return false;
    }

    final now = DateTime.now();
    if (!now.isAfter(session.endTime)) {
      return false;
    }

    await _client
        .from('session_members')
        .update({'status': 'absent'})
        .eq('session_id', session.id)
        .eq('status', 'pending');

    await _client
        .from('attendance_sessions')
        .update({'status': 'closed'})
        .eq('id', session.id)
        .eq('status', 'active');

    return true;
  }
}
