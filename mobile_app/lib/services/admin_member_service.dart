import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/group.dart';
import '../models/member.dart';

class AdminMemberService {
  AdminMemberService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<TeamMember>> fetchMembers() async {
    final rows = await _client
        .from('members')
        .select(
          'id, name, student_id, gender, phone, group_id, is_active, '
          'created_at, groups(name)',
        )
        .order('created_at', ascending: false);

    return rows.map(TeamMember.fromJson).toList();
  }

  Future<List<TeamGroup>> fetchGroups() async {
    final rows = await _client
        .from('groups')
        .select('id, name, description')
        .order('name', ascending: true);

    return rows.map(TeamGroup.fromJson).toList();
  }

  Future<void> createMember(MemberInput input) async {
    await _client.from('members').insert(input.toJson());
  }

  Future<void> updateMember(String memberId, MemberInput input) async {
    await _client.from('members').update(input.toJson()).eq('id', memberId);
  }

  Future<void> deleteMember(String memberId) async {
    await _client.from('members').delete().eq('id', memberId);
  }
}
