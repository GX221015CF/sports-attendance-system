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
                ? '已完成签到，迟到 ${preview.lateMinutes} 分钟'
                : '已完成签到，状态为正常',
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
    return Scaffold(
      appBar: AppBar(title: const Text('成员签到')),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _members.isEmpty && _errorMessage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ErrorState(
        title: '成员列表读取失败',
        message: _errorMessage!,
        retrying: _loading,
        onRetry: _loadMembers,
      );
    }

    final filteredMembers = _filteredMembers;

    return RefreshIndicator(
      onRefresh: _loadMembers,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _HeaderCard(session: widget.session, closed: _isExpiredOrClosed),
          if (_isExpiredOrClosed) ...[
            const SizedBox(height: 12),
            const _EndedNotice(),
          ],
          const SizedBox(height: 16),
          _SearchAndFilter(
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
          const SizedBox(height: 16),
          if (filteredMembers.isEmpty)
            const EmptyState(
              icon: Icons.search_off,
              title: '暂无成员',
              message: '当前筛选条件下没有成员记录。',
            )
          else
            ...filteredMembers.map(
              (member) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MemberCard(
                  member: member,
                  checking: _checkingMemberId == member.id,
                  onCheckin: member.status == 'pending' && !_isExpiredOrClosed
                      ? () => _handleCheckin(member)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.session, required this.closed});

  final AttendanceSession session;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.groups, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  session.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textStrong,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              StatusTag(status: closed ? 'closed' : 'active'),
            ],
          ),
          const SizedBox(height: 16),
          _TimeLine(
            icon: Icons.schedule,
            label: '规定签到',
            value: formatDateTime(session.requiredTime),
          ),
          const SizedBox(height: 10),
          _TimeLine(
            icon: Icons.flag_outlined,
            label: '结束时间',
            value: formatDateTime(session.endTime),
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
      padding: const EdgeInsets.all(14),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(
            '$label：',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textStrong,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchAndFilter extends StatelessWidget {
  const _SearchAndFilter({
    required this.controller,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onStatusChanged,
  });

  final TextEditingController controller;
  final String statusFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: '按姓名搜索',
              prefixIcon: const Icon(Icons.search),
              fillColor: AppTheme.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChipButton(
                  label: '全部',
                  value: 'all',
                  selectedValue: statusFilter,
                  onSelected: onStatusChanged,
                ),
                _FilterChipButton(
                  label: '未签到',
                  value: 'pending',
                  selectedValue: statusFilter,
                  onSelected: onStatusChanged,
                ),
                _FilterChipButton(
                  label: '正常',
                  value: 'normal',
                  selectedValue: statusFilter,
                  onSelected: onStatusChanged,
                ),
                _FilterChipButton(
                  label: '迟到',
                  value: 'late',
                  selectedValue: statusFilter,
                  onSelected: onStatusChanged,
                ),
                _FilterChipButton(
                  label: '缺勤',
                  value: 'absent',
                  selectedValue: statusFilter,
                  onSelected: onStatusChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onSelected,
  });

  final String label;
  final String value;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = value == selectedValue;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(value),
      selectedColor: AppTheme.primary.withValues(alpha: 0.14),
      backgroundColor: AppTheme.background,
      labelStyle: TextStyle(
        color: selected ? AppTheme.primary : AppTheme.textStrong,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
      side: BorderSide(
        color: selected
            ? AppTheme.primary
            : Colors.black.withValues(alpha: 0.06),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}
