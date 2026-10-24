import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/admin_session.dart';
import '../../models/session_member.dart';
import '../../services/admin_session_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/edit_remark_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/adaptive_page_body.dart';
import '../../widgets/error_state.dart';
import '../../widgets/status_tag.dart';

class AdminSessionDetailPage extends StatefulWidget {
  const AdminSessionDetailPage({
    super.key,
    required this.sessionId,
    this.sessionService,
  });
  final AdminSessionService? sessionService;

  final String sessionId;

  @override
  State<AdminSessionDetailPage> createState() => _AdminSessionDetailPageState();
}

class _AdminSessionDetailPageState extends State<AdminSessionDetailPage> {
  late final _sessionService = widget.sessionService ?? AdminSessionService();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  bool _loading = false;
  bool _closing = false;
  String? _errorMessage;
  String _keyword = '';
  String _statusFilter = 'all';
  AdminSession? _session;
  List<SessionMember> _members = const [];

  List<SessionMember> get _filteredMembers {
    return _members.where((member) {
      final matchesKeyword =
          _keyword.isEmpty || member.memberName.contains(_keyword);
      final matchesStatus =
          _statusFilter == 'all' || member.status == _statusFilter;

      return matchesKeyword && matchesStatus;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadDetail();
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

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _sessionService.fetchSessionDetail(widget.sessionId),
        _sessionService.fetchSessionMembers(widget.sessionId),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _session = results[0] as AdminSession;
        _members = results[1] as List<SessionMember>;
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

  Future<void> _confirmCloseSession() async {
    final session = _session;
    if (session == null || session.status != 'active' || _closing) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认结束本次签到？'),
        content: const Text('结束后，所有未签到成员将被标记为缺勤，且本次签到将关闭。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('确认结束'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _closeSession();
    }
  }

  Future<void> _closeSession() async {
    final session = _session;
    if (session == null || _closing) {
      return;
    }

    setState(() {
      _closing = true;
    });

    try {
      await _sessionService.closeSession(session.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已结束签到，未签到成员已标记为缺勤')));

      await _loadDetail();
    } on Object catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('结束签到失败，请稍后重试。')));
    } finally {
      if (mounted) {
        setState(() {
          _closing = false;
        });
      }
    }
  }

  Future<void> _openRemarkDialog(SessionMember member) async {
    final changed = await showEditRemarkSheet(
      context: context,
      memberName: member.memberName,
      statusLabel: _statusLabel(member.status),
      initialRemark: member.remark,
      onSave: (remark) => _sessionService.updateSessionMemberRemark(
        sessionMemberId: member.id,
        remark: remark,
      ),
    );

    if (changed != true || !mounted) {
      return;
    }

    await _loadDetail();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('备注已更新')));
  }

  String _statusLabel(String status) {
    return switch (status) {
      'normal' => '正常',
      'late' => '迟到',
      'absent' => '缺勤',
      _ => '未签到',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: _buildBody(context)));
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _session == null && _errorMessage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ErrorState(
        title: '签到详情读取失败',
        message: '无法读取签到详情，请检查网络连接后重试。',
        retrying: _loading,
        onRetry: _loadDetail,
      );
    }

    final session = _session;
    if (session == null) {
      return const EmptyState(
        icon: Icons.event_busy_outlined,
        title: '签到不存在',
        message: '该签到任务不存在或已被删除。',
      );
    }

    final members = _filteredMembers;
    return AdaptivePageBody(
      storageKey: 'admin-detail',
      toolbar: _TopBar(),
      summary: Column(
        children: [
          _SessionHeader(session: session),
          const SizedBox(height: 12),
          _StatsPanel(stats: session.stats),
          if (session.status == 'active') ...[
            const SizedBox(height: 12),
            _CloseSessionButton(
              closing: _closing,
              onClose: _confirmCloseSession,
            ),
          ],
        ],
      ),
      filters: LayoutBuilder(
        builder: (context, constraints) => _Filters(
          compact: constraints.maxWidth >= 720,
          controller: _searchController,
          statusFilter: _statusFilter,
          onSearchChanged: _updateSearchKeyword,
          onStatusChanged: (value) => setState(() => _statusFilter = value),
        ),
      ),
      onRefresh: _loadDetail,
      slivers: [
        if (members.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.search_off,
              title: '没有匹配成员',
              message: '请调整搜索关键字或状态筛选条件。',
            ),
          )
        else
          ResponsiveSliverCards(
            itemCount: members.length,
            itemBuilder: (context, index) => _DetailMemberCard(
              member: members[index],
              savingRemark: false,
              onEditRemark: () => _openRemarkDialog(members[index]),
            ),
          ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
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
              '签到详情',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textStrong,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.session});

  final AdminSession session;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _SessionStatusTag(status: session.status),
            ],
          ),
          const SizedBox(height: 14),
          _HeaderLine(
            label: '规定签到',
            value: formatDateTime(session.requiredTime),
          ),
          const SizedBox(height: 7),
          _HeaderLine(label: '结束时间', value: formatDateTime(session.endTime)),
          const SizedBox(height: 7),
          _HeaderLine(label: '创建时间', value: formatDateTime(session.createdAt)),
        ],
      ),
    );
  }
}

class _HeaderLine extends StatelessWidget {
  const _HeaderLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _SessionStatusTag extends StatelessWidget {
  const _SessionStatusTag({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final active = status == 'active';
    final color = active ? AppTheme.success : Colors.white70;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: active ? 0.16 : 0.10),
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

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.stats});

  final SessionStats stats;

  @override
  Widget build(BuildContext context) {
    final attendanceRate = stats.total == 0 ? 0 : stats.checked / stats.total;
    final rateText = '${(attendanceRate * 100).toStringAsFixed(0)}%';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatPill(label: '参与', value: stats.total, color: AppTheme.primary),
          _StatPill(label: '已签', value: stats.checked, color: AppTheme.success),
          _StatPill(
            label: '未签',
            value: stats.pending,
            color: AppTheme.textMuted,
          ),
          _StatPill(label: '正常', value: stats.normal, color: AppTheme.success),
          _StatPill(label: '迟到', value: stats.late, color: AppTheme.secondary),
          _StatPill(label: '缺勤', value: stats.absent, color: AppTheme.error),
          _RatePill(rateText: rateText),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
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

class _RatePill extends StatelessWidget {
  const _RatePill({required this.rateText});

  final String rateText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        '出勤率 $rateText',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.secondary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CloseSessionButton extends StatelessWidget {
  const _CloseSessionButton({required this.closing, required this.onClose});

  final bool closing;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: closing ? null : onClose,
        icon: closing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.lock_clock_outlined),
        label: Text(closing ? '结束中...' : '结束签到'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.error,
          side: const BorderSide(color: AppTheme.error),
        ),
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
        hintText: '按姓名搜索',
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
            label: '未签到',
            value: 'pending',
            selected: statusFilter == 'pending',
            onSelected: onStatusChanged,
          ),
          _FilterChipItem(
            label: '正常',
            value: 'normal',
            selected: statusFilter == 'normal',
            onSelected: onStatusChanged,
          ),
          _FilterChipItem(
            label: '迟到',
            value: 'late',
            selected: statusFilter == 'late',
            onSelected: onStatusChanged,
          ),
          _FilterChipItem(
            label: '缺勤',
            value: 'absent',
            selected: statusFilter == 'absent',
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
          Expanded(flex: 3, child: chips),
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

class _DetailMemberCard extends StatelessWidget {
  const _DetailMemberCard({
    required this.member,
    required this.savingRemark,
    required this.onEditRemark,
  });

  final SessionMember member;
  final bool savingRemark;
  final VoidCallback onEditRemark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        member.memberName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppTheme.textStrong,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    StatusTag(status: member.status),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${member.groupName} · ${member.studentId} · ${member.gender}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _statusLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: member.status == 'late'
                        ? AppTheme.secondary
                        : AppTheme.textMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '备注：${member.remark.trim().isEmpty ? '暂无备注' : member.remark}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: savingRemark ? null : onEditRemark,
                    icon: const Icon(Icons.edit_note_outlined, size: 18),
                    label: const Text('编辑备注'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _statusLine {
    final checkinText = member.checkinTime == null
        ? '签到时间 -'
        : '签到时间 ${formatDateTime(member.checkinTime!)}';

    if (member.status == 'late' && member.lateMinutes > 0) {
      return '$checkinText · 迟到 ${member.lateMinutes} 分钟';
    }

    return '$checkinText · 迟到 ${member.lateMinutes} 分钟';
  }
}
