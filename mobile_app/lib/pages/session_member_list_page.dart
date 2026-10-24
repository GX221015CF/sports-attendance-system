import 'package:flutter/material.dart';

import '../models/attendance_session.dart';
import '../models/session_member.dart';
import '../services/attendance_service.dart';
import '../services/time_service.dart';
import '../widgets/attendance_workspace.dart';
import '../widgets/checkin_confirm_dialog.dart';
import '../widgets/edit_remark_dialog.dart';
import '../widgets/error_state.dart';
import '../widgets/member_card.dart';

class SessionMemberListPage extends StatefulWidget {
  const SessionMemberListPage({
    super.key,
    required this.session,
    this.attendanceService,
  });

  final AttendanceService? attendanceService;

  final AttendanceSession session;

  @override
  State<SessionMemberListPage> createState() => _SessionMemberListPageState();
}

class _SessionMemberListPageState extends State<SessionMemberListPage> {
  late final AttendanceService _attendanceService =
      widget.attendanceService ?? AttendanceService();
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

  Future<void> _openRemarkDialog(SessionMember member) async {
    final changed = await showEditRemarkSheet(
      context: context,
      memberName: member.memberName,
      statusLabel: _statusLabel(member.status),
      initialRemark: member.remark,
      onSave: (remark) => _attendanceService.updateSessionMemberRemark(
        sessionMemberId: member.id,
        remark: remark,
      ),
    );

    if (changed != true || !mounted) {
      return;
    }

    await _loadMembers();

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
    if (_loading && _members.isEmpty && _errorMessage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        child: ErrorState(
          title: '数据加载失败',
          message: '成员签到列表读取失败，请检查网络连接后重试。',
          retrying: _loading,
          onRetry: _loadMembers,
        ),
      );
    }

    return AttendanceWorkspace(
      session: widget.session,
      members: _members,
      filteredMembers: _filteredMembers,
      ended: _isExpiredOrClosed,
      local: false,
      searchController: _searchController,
      statusFilter: _statusFilter,
      onSearchChanged: (value) => setState(() => _keyword = value.trim()),
      onStatusChanged: (value) => setState(() => _statusFilter = value),
      onRefresh: _loadMembers,
      loading: _loading,
      memberBuilder: (member) => MemberCard(
        member: member,
        checking: _checkingMemberId == member.id,
        onCheckin: member.status == 'pending' && !_isExpiredOrClosed
            ? () => _handleCheckin(member)
            : null,
        onEditRemark: () => _openRemarkDialog(member),
      ),
    );
  }
}
