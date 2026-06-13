import 'package:flutter/material.dart';

import '../models/attendance_session.dart';
import '../models/session_member.dart';
import '../services/attendance_service.dart';
import '../services/time_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import '../widgets/checkin_confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/member_card.dart';
import '../widgets/status_tag.dart';

class SessionMemberListPage extends StatefulWidget {
  const SessionMemberListPage({super.key, required this.session});

  final AttendanceSession session;

  @override
  State<SessionMemberListPage> createState() => _SessionMemberListPageState();
}

class _SessionMemberListPageState extends State<SessionMemberListPage> {
  final AttendanceService _attendanceService = AttendanceService();
  final TimeService _timeService = TimeService();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = false;
  bool _closed = false;
  bool _autoCloseNotified = false;
  String _statusFilter = 'all';
  String _keyword = '';
  String? _errorMessage;
  String? _checkingMemberId;
  List<SessionMember> _members = const [];

  bool get _isExpiredOrClosed =>
      _closed ||
      widget.session.status == 'closed' ||
      DateTime.now().isAfter(widget.session.endTime);

  _MemberStats get _stats => _MemberStats.fromMembers(_members);

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
    _closed = widget.session.status == 'closed';
    _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _closeIfExpired() async {
    final closed = await _attendanceService.closeExpiredSessionIfNeeded(
      widget.session,
    );

    if (!closed) {
      return;
    }

    _closed = true;

    if (mounted && !_autoCloseNotified) {
      _autoCloseNotified = true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('本次签到已结束，未签到成员已标记为缺勤')));
    }
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await _closeIfExpired();

      final members = await _attendanceService.getSessionMembers(
        widget.session.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _members = members;
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

  Future<void> _handleCheckin(SessionMember member) async {
    if (member.status != 'pending' || _checkingMemberId != null) {
      return;
    }

    final now = DateTime.now();
    final preview = _timeService.previewCheckin(
      now: now,
      requiredTime: widget.session.requiredTime,
      endTime: widget.session.endTime,
    );

    if (!preview.canCheckin) {
      await _loadMembers();
      if (!mounted) {
        return;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          CheckinConfirmDialog(member: member, now: now, preview: preview),
    );

    if (confirmed != true || !preview.canCheckin) {
      return;
    }

    setState(() {
      _checkingMemberId = member.id;
    });

    try {
      await _attendanceService.checkinMember(
        sessionMemberId: member.id,
        status: preview.status,
        checkinTime: now,
        lateMinutes: preview.lateMinutes,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            preview.status == 'late'
                ? '签到成功，迟到 ${preview.lateMinutes} 分钟'
                : '签到成功，状态为正常',
          ),
        ),
      );

      await _loadMembers();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('签到失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _checkingMemberId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: _buildBody(context)));
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _members.isEmpty && _errorMessage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ErrorState(
        title: '数据加载失败',
        message: '成员签到列表读取失败，请检查网络连接后重试。',
        retrying: _loading,
        onRetry: _loadMembers,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape =
            constraints.maxWidth > constraints.maxHeight ||
            constraints.maxWidth >= 720;
        final horizontalPadding = isLandscape ? 18.0 : 20.0;
        final filteredMembers = _filteredMembers;

        return RefreshIndicator(
          onRefresh: _loadMembers,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              20,
            ),
            children: [
              _TopBar(title: widget.session.title, compact: isLandscape),
              SizedBox(height: isLandscape ? 10 : 14),
              _SessionHeader(
                session: widget.session,
                ended: _isExpiredOrClosed,
                compact: isLandscape,
              ),
              SizedBox(height: isLandscape ? 10 : 14),
              _OverviewStrip(stats: _stats, compact: isLandscape),
              if (_isExpiredOrClosed) ...[
                const SizedBox(height: 10),
                const _EndedNotice(),
              ],
              SizedBox(height: isLandscape ? 10 : 14),
              _SearchAndFilters(
                compact: isLandscape,
                controller: _searchController,
                statusFilter: _statusFilter,
                onSearchChanged: (value) {
                  setState(() {
                    _keyword = value.trim();
                  });
                },
                onStatusChanged: (value) {
                  setState(() {
                    _statusFilter = value;
                  });
                },
              ),
              SizedBox(height: isLandscape ? 10 : 14),
              if (filteredMembers.isEmpty)
                const EmptyState(
                  icon: Icons.search_off,
                  title: '暂无成员',
                  message: '当前筛选条件下没有成员记录。',
                )
              else
                _MemberList(
                  members: filteredMembers,
                  isLandscape: isLandscape,
                  checkingMemberId: _checkingMemberId,
                  canCheckin: !_isExpiredOrClosed,
                  onCheckin: _handleCheckin,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MemberStats {
  const _MemberStats({
    required this.total,
    required this.checked,
    required this.pending,
    required this.normal,
    required this.late,
    required this.absent,
  });

  factory _MemberStats.fromMembers(List<SessionMember> members) {
    var pending = 0;
    var normal = 0;
    var late = 0;
    var absent = 0;

    for (final member in members) {
      switch (member.status) {
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

    return _MemberStats(
      total: members.length,
      checked: normal + late,
      pending: pending,
      normal: normal,
      late: late,
      absent: absent,
    );
  }

  final int total;
  final int checked;
  final int pending;
  final int normal;
  final int late;
  final int absent;

  double get attendanceRate => total == 0 ? 0 : checked / total;
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.compact});

  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 54 : 64,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh, color: AppTheme.primary),
            onPressed: () => context
                .findAncestorStateOfType<_SessionMemberListPageState>()
                ?._loadMembers(),
          ),
        ],
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.session,
    required this.ended,
    required this.compact,
  });

  final AttendanceSession session;
  final bool ended;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 42 : 48,
            height: compact ? 42 : 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.timer_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ended ? '本次签到已结束' : '本次签到进行中',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatDateTime(session.requiredTime).substring(11)} - ${formatDateTime(session.endTime).substring(11)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          StatusTag(status: ended ? 'absent' : 'normal'),
        ],
      ),
    );
  }
}

class _OverviewStrip extends StatelessWidget {
  const _OverviewStrip({required this.stats, required this.compact});

  final _MemberStats stats;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final rate = '${(stats.attendanceRate * 100).toStringAsFixed(0)}%';
    final items = [
      _OverviewItem('参与', stats.total.toString(), AppTheme.primary),
      _OverviewItem('已签', stats.checked.toString(), AppTheme.success),
      _OverviewItem('未签', stats.pending.toString(), AppTheme.textMuted),
      _OverviewItem('正常', stats.normal.toString(), AppTheme.success),
      _OverviewItem('迟到', stats.late.toString(), AppTheme.secondary),
      _OverviewItem('缺勤', stats.absent.toString(), const Color(0xFFB91C1C)),
      _OverviewItem('出勤率', rate, AppTheme.secondary),
    ];

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: compact ? 8 : 10,
        runSpacing: compact ? 8 : 10,
        children: items.map((item) {
          final width = compact ? 88.0 : 92.0;
          return SizedBox(
            width: width,
            child: _OverviewTile(item: item, highlight: item.label == '出勤率'),
          );
        }).toList(),
      ),
    );
  }
}

class _OverviewItem {
  const _OverviewItem(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({required this.item, required this.highlight});

  final _OverviewItem item;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: highlight ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: item.color,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndedNotice extends StatelessWidget {
  const _EndedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.24)),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_clock, color: Colors.deepOrange),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '本次签到已结束，不能继续签到。',
              style: TextStyle(
                color: Colors.deepOrange,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [search, const SizedBox(height: 10), chips],
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
    required this.isLandscape,
    required this.checkingMemberId,
    required this.canCheckin,
    required this.onCheckin,
  });

  final List<SessionMember> members;
  final bool isLandscape;
  final String? checkingMemberId;
  final bool canCheckin;
  final ValueChanged<SessionMember> onCheckin;

  @override
  Widget build(BuildContext context) {
    if (isLandscape) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: members.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 3.85,
        ),
        itemBuilder: (context, index) {
          final member = members[index];
          return MemberCard(
            member: member,
            checking: checkingMemberId == member.id,
            onCheckin: member.status == 'pending' && canCheckin
                ? () => onCheckin(member)
                : null,
          );
        },
      );
    }

    return Column(
      children: [
        for (final member in members)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MemberCard(
              member: member,
              checking: checkingMemberId == member.id,
              onCheckin: member.status == 'pending' && canCheckin
                  ? () => onCheckin(member)
                  : null,
            ),
          ),
      ],
    );
  }
}
