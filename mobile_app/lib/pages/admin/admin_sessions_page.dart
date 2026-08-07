import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/admin_session.dart';
import '../../services/admin_session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import 'admin_create_session_page.dart';
import 'admin_session_detail_page.dart';

class AdminSessionsPage extends StatefulWidget {
  const AdminSessionsPage({super.key});

  @override
  State<AdminSessionsPage> createState() => _AdminSessionsPageState();
}

class _AdminSessionsPageState extends State<AdminSessionsPage> {
  final _sessionService = AdminSessionService();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _loading = false;
  String? _errorMessage;
  String _keyword = '';
  String _statusFilter = 'all';
  List<AdminSession> _sessions = const [];

  List<AdminSession> get _filteredSessions {
    return _sessions.where((session) {
      final matchesKeyword =
          _keyword.isEmpty || session.title.contains(_keyword);
      final matchesStatus =
          _statusFilter == 'all' || session.status == _statusFilter;
      return matchesKeyword && matchesStatus;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadSessions();
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

  Future<void> _loadSessions() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final sessions = await _sessionService.fetchSessionsWithStats();

      if (!mounted) {
        return;
      }

      setState(() {
        _sessions = sessions;
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

  Future<void> _openCreateSessionPage() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AdminCreateSessionPage()),
    );

    if (created == true) {
      await _loadSessions();
    }
  }

  Future<void> _openSessionDetail(AdminSession session) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AdminSessionDetailPage(sessionId: session.id),
      ),
    );

    await _loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSessionPage,
        backgroundColor: AppTheme.secondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task_outlined),
        label: const Text('创建签到'),
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _sessions.isEmpty && _errorMessage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ErrorState(
        title: '签到任务读取失败',
        message: '无法读取签到任务列表，请检查网络连接后重试。',
        retrying: _loading,
        onRetry: _loadSessions,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth > constraints.maxHeight ||
            constraints.maxWidth >= 720;
        final sessions = _filteredSessions;

        return RefreshIndicator(
          onRefresh: _loadSessions,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              compact ? 28 : 20,
              compact ? 8 : 14,
              compact ? 28 : 20,
              92,
            ),
            children: [
              _TopBar(onCreate: _openCreateSessionPage),
              SizedBox(height: compact ? 12 : 18),
              _SummaryHeader(total: _sessions.length),
              SizedBox(height: compact ? 12 : 16),
              _Filters(
                compact: compact,
                controller: _searchController,
                statusFilter: _statusFilter,
                onSearchChanged: _updateSearchKeyword,
                onStatusChanged: (value) {
                  setState(() {
                    _statusFilter = value;
                  });
                },
              ),
              SizedBox(height: compact ? 12 : 16),
              if (sessions.isEmpty)
                const EmptyState(
                  icon: Icons.event_note_outlined,
                  title: '暂无签到任务',
                  message: '点击右下角创建签到，发布新的训练签到任务。',
                )
              else if (compact)
                _SessionGrid(
                  sessions: sessions,
                  onOpenDetail: _openSessionDetail,
                )
              else
                _SessionList(
                  sessions: sessions,
                  onOpenDetail: _openSessionDetail,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onCreate});

  final VoidCallback onCreate;

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
              '签到任务',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textStrong,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: '创建签到',
            onPressed: onCreate,
            icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
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
            child: const Icon(Icons.fact_check_outlined, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '签到任务管理',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '当前共 $total 个签到任务',
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
    required this.controller,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onStatusChanged,
  });

  final bool compact;
  final TextEditingController controller;
  final String statusFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final search = TextField(
      controller: controller,
      onChanged: onSearchChanged,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.search),
        hintText: '按标题搜索',
      ),
    );

    final chips = SingleChildScrollView(
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
            label: '进行中',
            value: 'active',
            selected: statusFilter == 'active',
            onSelected: onStatusChanged,
          ),
          _FilterChipItem(
            label: '已结束',
            value: 'closed',
            selected: statusFilter == 'closed',
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
          Expanded(child: chips),
        ],
      );
    }

    return Column(
      children: [
        search,
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerLeft, child: chips),
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

class _SessionList extends StatelessWidget {
  const _SessionList({required this.sessions, required this.onOpenDetail});

  final List<AdminSession> sessions;
  final ValueChanged<AdminSession> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final session in sessions)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SessionCard(
              session: session,
              onOpenDetail: () => onOpenDetail(session),
            ),
          ),
      ],
    );
  }
}

class _SessionGrid extends StatelessWidget {
  const _SessionGrid({required this.sessions, required this.onOpenDetail});

  final List<AdminSession> sessions;
  final ValueChanged<AdminSession> onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sessions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 254,
      ),
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _SessionCard(
          session: session,
          onOpenDetail: () => onOpenDetail(session),
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onOpenDetail});

  final AdminSession session;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpenDetail,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.032),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textStrong,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _SessionStatusTag(status: session.status),
                ],
              ),
              const SizedBox(height: 10),
              _TimeLine(
                icon: Icons.schedule,
                label: '规定',
                value: formatDateTime(session.requiredTime),
              ),
              const SizedBox(height: 6),
              _TimeLine(
                icon: Icons.alarm_off_outlined,
                label: '结束',
                value: formatDateTime(session.endTime),
              ),
              const SizedBox(height: 12),
              _StatsWrap(stats: session.stats),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onOpenDetail,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('查看详情'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionStatusTag extends StatelessWidget {
  const _SessionStatusTag({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final active = status == 'active';
    final color = active ? AppTheme.success : AppTheme.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? '进行中' : '已结束',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TimeLine extends StatelessWidget {
  const _TimeLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.textMuted),
        const SizedBox(width: 5),
        Text(
          '$label ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsWrap extends StatelessWidget {
  const _StatsWrap({required this.stats});

  final SessionStats stats;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatPill(label: '参与', value: stats.total, color: AppTheme.primary),
        _StatPill(label: '已签', value: stats.checked, color: AppTheme.success),
        _StatPill(label: '未签', value: stats.pending, color: AppTheme.textMuted),
        _StatPill(label: '迟到', value: stats.late, color: AppTheme.secondary),
        _StatPill(label: '缺勤', value: stats.absent, color: AppTheme.error),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
