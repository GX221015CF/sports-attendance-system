import 'package:flutter/material.dart';

import 'dart:async';

import '../../models/group.dart';
import '../../services/admin_group_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/admin_group_card.dart';
import '../../widgets/admin/group_form_sheet.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/form_surface.dart';
import '../../widgets/adaptive_page_body.dart';
import '../../widgets/error_state.dart';

class AdminGroupsPage extends StatefulWidget {
  const AdminGroupsPage({super.key, this.groupService});
  final AdminGroupService? groupService;

  @override
  State<AdminGroupsPage> createState() => _AdminGroupsPageState();
}

class _AdminGroupsPageState extends State<AdminGroupsPage> {
  late final _groupService = widget.groupService ?? AdminGroupService();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _loading = false;
  String? _errorMessage;
  String _keyword = '';
  String? _deletingGroupId;
  List<AdminGroupSummary> _groups = const [];

  List<AdminGroupSummary> get _filteredGroups {
    return _groups.where((summary) {
      return _keyword.isEmpty || summary.group.name.contains(_keyword);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _updateSearchKeyword(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      final keyword = value.trim();
      if (!mounted || _keyword == keyword) {
        return;
      }
      setState(() {
        _keyword = keyword;
      });
    });
  }

  Future<void> _loadGroups() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final groups = await _groupService.fetchGroupsWithMemberCount();

      if (!mounted) {
        return;
      }

      setState(() {
        _groups = groups;
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

  Future<void> _openGroupForm([TeamGroup? group]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 960),
      sheetAnimationStyle: formSheetAnimationStyle(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => GroupFormSheet(
        group: group,
        onSubmit: (input) {
          if (group == null) {
            return _groupService.createGroup(input);
          }
          return _groupService.updateGroup(group.id, input);
        },
      ),
    );

    if (changed != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(group == null ? '分组已新增' : '分组已更新')));

    await _loadGroups();
  }

  Future<void> _confirmDelete(AdminGroupSummary summary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除该分组？'),
        content: const Text('删除分组后，该分组下成员将变为未分组。'),
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
      await _deleteGroup(summary.group);
    }
  }

  Future<void> _deleteGroup(TeamGroup group) async {
    if (_deletingGroupId != null) {
      return;
    }

    setState(() {
      _deletingGroupId = group.id;
    });

    try {
      await _groupService.deleteGroup(group.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('分组已删除，相关成员已变为未分组')));

      await _loadGroups();
    } on Object catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('分组删除失败，请稍后重试。')));
    } finally {
      if (mounted) {
        setState(() {
          _deletingGroupId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _openGroupForm(),
        backgroundColor: AppTheme.secondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('新增分组'),
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _groups.isEmpty && _errorMessage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ErrorState(
        title: '分组读取失败',
        message: '无法读取分组列表，请检查网络连接或 Supabase 配置后重试。',
        retrying: _loading,
        onRetry: _loadGroups,
      );
    }

    final groups = _filteredGroups;
    return AdaptivePageBody(
      storageKey: 'admin-groups',
      toolbar: _TopBar(onRefresh: _loading ? null : _loadGroups),
      summary: _SummaryHeader(total: _groups.length),
      filters: TextField(
        controller: _searchController,
        onChanged: _updateSearchKeyword,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: '按分组名称搜索',
        ),
      ),
      onRefresh: _loadGroups,
      bottomPadding: 92,
      slivers: [
        if (groups.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.category_outlined,
              title: '暂无分组',
              message: '请调整搜索，或点击新增分组。',
            ),
          )
        else
          ResponsiveSliverCards(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final summary = groups[index];
              return AdminGroupCard(
                key: ValueKey(summary.group.id),
                summary: summary,
                deleting: _deletingGroupId == summary.group.id,
                onEdit: () => _openGroupForm(summary.group),
                onDelete: () => _confirmDelete(summary),
              );
            },
          ),
      ],
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
              '分组管理',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textStrong,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: '刷新分组',
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
            child: const Icon(Icons.category_outlined, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '训练分组库',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '当前共 $total 个分组',
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
