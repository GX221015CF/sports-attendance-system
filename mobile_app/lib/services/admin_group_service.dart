import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/group.dart';

class AdminGroupSummary {
  const AdminGroupSummary({required this.group, required this.memberCount});

  final TeamGroup group;
  final int memberCount;
}

class AdminGroupService {
  AdminGroupService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<AdminGroupSummary>> fetchGroupsWithMemberCount() async {
    final results = await Future.wait([
      _client
          .from('groups')
          .select('id, name, description, created_at')
          .order('created_at', ascending: false),
      _client.from('members').select('group_id'),
    ]);

    final groupRows = results[0] as List<dynamic>;
    final memberRows = results[1] as List<dynamic>;
    final counts = <String, int>{};

    for (final row in memberRows.cast<Map<String, dynamic>>()) {
      final groupId = row['group_id'] as String?;
      if (groupId == null) {
        continue;
      }
      counts[groupId] = (counts[groupId] ?? 0) + 1;
    }

    return groupRows.cast<Map<String, dynamic>>().map((row) {
      final group = TeamGroup.fromJson(row);
      return AdminGroupSummary(
        group: group,
        memberCount: counts[group.id] ?? 0,
      );
    }).toList();
  }

  Future<void> createGroup(GroupInput input) async {
    await _client.from('groups').insert(input.toJson());
  }

  Future<void> updateGroup(String groupId, GroupInput input) async {
    await _client.from('groups').update(input.toJson()).eq('id', groupId);
  }

  Future<void> deleteGroup(String groupId) async {
    await _client.from('groups').delete().eq('id', groupId);
  }
}
