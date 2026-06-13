import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardStats {
  const AdminDashboardStats({
    required this.activeMembers,
    required this.groups,
    required this.activeSessions,
    required this.closedSessions,
    required this.pendingCheckins,
    required this.lateCheckins,
  });

  final int activeMembers;
  final int groups;
  final int activeSessions;
  final int closedSessions;
  final int pendingCheckins;
  final int lateCheckins;
}

class AdminDashboardService {
  AdminDashboardService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<AdminDashboardStats> fetchDashboardStats() async {
    final results = await Future.wait<int>([
      _count('members', column: 'is_active', value: true),
      _count('groups'),
      _count('attendance_sessions', column: 'status', value: 'active'),
      _count('attendance_sessions', column: 'status', value: 'closed'),
      _count('session_members', column: 'status', value: 'pending'),
      _count('session_members', column: 'status', value: 'late'),
    ]);

    return AdminDashboardStats(
      activeMembers: results[0],
      groups: results[1],
      activeSessions: results[2],
      closedSessions: results[3],
      pendingCheckins: results[4],
      lateCheckins: results[5],
    );
  }

  Future<int> _count(String table, {String? column, Object? value}) async {
    var query = _client.from(table).count(CountOption.exact);

    if (column != null) {
      query = query.eq(column, value as Object);
    }

    return await query;
  }
}
