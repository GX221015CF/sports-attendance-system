import 'package:flutter/material.dart';

import '../../models/group.dart';
import '../../models/member.dart';
import '../../services/admin_member_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/admin_member_card.dart';
import '../../widgets/admin/member_form_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';

class AdminMembersPage extends StatefulWidget {
  const AdminMembersPage({super.key});

  @override
  State<AdminMembersPage> createState() => _AdminMembersPageState();
}

class _AdminMembersPageState extends State<AdminMembersPage> {
  final _memberService = AdminMemberService();
  final _searchController = TextEditingController();

  bool _loading = false;
  String? _errorMessage;
  String _keyword = '';
  String? _groupFilter;
  String _statusFilter = 'all';
  String? _deletingMemberId;
  List<TeamMember> _members = const [];
  List<TeamGroup> _groups = const [];

  List<TeamMember> get _filteredMembers {
    return _members.where((member) {
      final matchesKeyword = _keyword.isEmpty || member.name.contains(_keyword);
      final matchesGroup =
          _groupFilter == null || member.groupId == _groupFilter;
      final matchesStatus =
          _statusFilter == 'all' ||
          (_statusFilter == 'active' && member.isActive) ||
          (_statusFilter == 'inactive' && !member.isActive);

      return matchesKeyword && matchesGroup && matchesStatus;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _memberService.fetchMembers(),
        _memberService.fetchGroups(),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _members = results[0] as List<TeamMember>;
        _groups = results[1] as List<TeamGroup>;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openMemberForm([TeamMember? member]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => MemberFormSheet(
        groups: _groups,
        member: member,
        onSubmit: (input) {
          if (member == null) {
            return _memberService.createMember(input);
          }
          return _memberService.updateMember(member.id, input);
        },
      ),
    );

    if (changed != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(member == null ? '成员已新增' : '成员已更新')));

    await _loadData();
  }

  Future<void> _confirmDelete(TeamMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除该成员？'),
        content: Text('删除后将无法在成员列表中看到 。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteMember(member);
    }
  }

  Future<void> _deleteMember(TeamMember member) async {
    if (_deletingMemberId != null) {
      return;
    }

    setState(() {
      _deletingMemberId = member.id;
    });

    try {
      await _memberService.deleteMember(member.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('成员已删除')));

      await _loadData();
    } on Object catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('删除失败。该成员可能已有签到记录，暂时不能直接删除。')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingMemberId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _openMemberForm(),
        backgroundColor: AppTheme.secondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('新增成员'),
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _members.isEmpty && _errorMessage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ErrorState(
        title: '成员读取失败',
        message: '无法读取成员列表，请检查网络连接或 Supabase 配置后重试。',
        retrying: _loading,
        onRetry: _loadData,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth > constraints.maxHeight ||
            constraints.maxWidth >= 720;
        final filteredMembers = _filteredMembers;

        return RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              compact ? 28 : 20,
              compact ? 8 : 14,
              compact ? 28 : 20,
              92,
            ),
            children: [
              _TopBar(onRefresh: _loading ? null : _loadData),
              SizedBox(height: compact ? 12 : 18),
              _SummaryHeader(total: _members.length),
              SizedBox(height: compact ? 12 : 16),
              _Filters(
                compact: compact,
                groups: _groups,
                controller: _searchController,
                groupFilter: _groupFilter,
                statusFilter: _statusFilter,
                onSearchChanged: (value) {
                  setState(() {
                    _keyword = value.trim();
                  });
                },
                onGroupChanged: (value) {
                  setState(() {
                    _groupFilter = value?.isEmpty == true ? null : value;
                  });
                },
                onStatusChanged: (value) {
                  setState(() {
                    _statusFilter = value;
                  });
                },
              ),
              SizedBox(height: compact ? 12 : 16),
              if (filteredMembers.isEmpty)
                const EmptyState(
                  icon: Icons.group_off_outlined,
                  title: '暂无成员',
                  message: '当前筛选条件下没有成员。可以点击右下角新增成员，或点击右上角刷新。',
                )
              else if (compact)
                _MemberGrid(
                  members: filteredMembers,
                  deletingMemberId: _deletingMemberId,
                  onEdit: _openMemberForm,
                  onDelete: _confirmDelete,
                )
              else
                _MemberList(
                  members: filteredMembers,
                  deletingMemberId: _deletingMemberId,
                  onEdit: _openMemberForm,
                  onDelete: _confirmDelete,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onRefresh});

  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '成员管理',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textStrong,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: '刷新成员',
            icon: const Icon(Icons.refresh, color: AppTheme.primary),
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.groups_2_outlined, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '队员资料库',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '当前共  名成员',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.compact,
    required this.groups,
    required this.controller,
    required this.groupFilter,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onGroupChanged,
    required this.onStatusChanged,
  });

  final bool compact;
  final List<TeamGroup> groups;
  final TextEditingController controller;
  final String? groupFilter;
  final String statusFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onGroupChanged;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final search = TextField(
      controller: controller,
      onChanged: onSearchChanged,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: '按姓名搜索',
      ),
    );

    final groupSelect = DropdownButtonFormField<String>(
      initialValue: groupFilter ?? '',
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.groups_2_outlined),
        labelText: '分组',
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('全部分组')),
        ...groups.map(
          (group) => DropdownMenuItem(value: group.id, child: Text(group.name)),
        ),
      ],
      onChanged: onGroupChanged,
    );

    final statusChips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChipItem(
            label: '全部',
            value: 'all',
            selected: statusFilter == 'all',
            onSelected: onStatusChanged,
          ),
          _FilterChipItem(
            label: '在队',
            value: 'active',
            selected: statusFilter == 'active',
            onSelected: onStatusChanged,
          ),
          _FilterChipItem(
            label: '离队',
            value: 'inactive',
            selected: statusFilter == 'inactive',
            onSelected: onStatusChanged,
          ),
        ],
      ),
    );

    if (compact) {
      return Row(
        children: [
          Expanded(flex: 2, child: search),
          const SizedBox(width: 12),
          Expanded(child: groupSelect),
          const SizedBox(width: 12),
          Expanded(child: statusChips),
        ],
      );
    }

    return Column(
      children: [
        search,
        const SizedBox(height: 10),
        groupSelect,
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerLeft, child: statusChips),
      ],
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(value),
      ),
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({
    required this.members,
    required this.deletingMemberId,
    required this.onEdit,
    required this.onDelete,
  });

  final List<TeamMember> members;
  final String? deletingMemberId;
  final ValueChanged<TeamMember> onEdit;
  final ValueChanged<TeamMember> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final member in members)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AdminMemberCard(
              member: member,
              deleting: deletingMemberId == member.id,
              onEdit: () => onEdit(member),
              onDelete: () => onDelete(member),
            ),
          ),
      ],
    );
  }
}

class _MemberGrid extends StatelessWidget {
  const _MemberGrid({
    required this.members,
    required this.deletingMemberId,
    required this.onEdit,
    required this.onDelete,
  });

  final List<TeamMember> members;
  final String? deletingMemberId;
  final ValueChanged<TeamMember> onEdit;
  final ValueChanged<TeamMember> onDelete;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: members.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 210,
      ),
      itemBuilder: (context, index) {
        final member = members[index];
        return AdminMemberCard(
          member: member,
          deleting: deletingMemberId == member.id,
          onEdit: () => onEdit(member),
          onDelete: () => onDelete(member),
        );
      },
    );
  }
}

