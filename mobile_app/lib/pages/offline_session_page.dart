import 'package:flutter/material.dart';

import '../models/offline_session.dart';
import '../models/session_member.dart';
import '../services/offline_attendance_service.dart';
import '../services/interaction_audio.dart';
import '../widgets/attendance_motion.dart';
import '../widgets/attendance_workspace.dart';
import '../widgets/error_state.dart';
import '../widgets/edit_remark_dialog.dart';
import '../widgets/member_card.dart';

class OfflineSessionPage extends StatefulWidget {
  const OfflineSessionPage({
    super.key,
    required this.local,
    required this.sessionId,
  });
  final OfflineAttendanceService local;
  final String sessionId;
  @override
  State<OfflineSessionPage> createState() => _OfflineSessionPageState();
}

class _OfflineSessionPageState extends State<OfflineSessionPage> {
  OfflineSession? _session;
  List<SessionMember> _members = [];
  final _searchController = TextEditingController();
  String _keyword = '';
  String _filter = 'all';
  bool _busy = false;
  String? _checkingMemberId;
  int _successSequence = 0;
  String? _successMessage;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _load() async {
    try {
      await widget.local.closeSession(widget.sessionId, onlyIfExpired: true);
      final s = await widget.local.getSession(widget.sessionId);
      final members = await widget.local.getMembers(widget.sessionId);
      if (mounted) {
        setState(() {
          _session = s;
          _members = members;
          _error = null;
        });
      }
    } on Object catch (_) {
      if (mounted) setState(() => _error = '本机任务读取失败，请重试。');
    }
  }

  Future<void> _checkin(SessionMember member) async {
    final s = _session;
    if (_busy ||
        member.status != 'pending' ||
        !_members.any((m) => m.id == member.id && m.status == 'pending') ||
        s == null ||
        s.isClosed ||
        !s.canEdit) {
      return;
    }
    setState(() {
      _busy = true;
      _checkingMemberId = member.id;
    });
    InteractionAudio.instance.play(SoundCue.tap);
    try {
      // The local transaction remains authoritative for timing and editability.
      final saved = await widget.local.checkin(widget.sessionId, member.id);
      if (!mounted) return;
      setState(() {
        _members = _members.map((m) => m.id == saved.id ? saved : m).toList();
        _successMessage = saved.status == 'late'
            ? '${member.memberName} · 已保存在本机，迟到 ${saved.lateMinutes} 分钟'
            : '${member.memberName} · 正常签到已保存在本机，尚未上传';
        _successSequence++;
      });
    } on Object catch (_) {
      _message('签到未保存：可能已签到、已截止或本地写入失败，请刷新确认。');
      InteractionAudio.instance.play(SoundCue.failure);
    } finally {
      if (mounted) {
        await _load();
        if (mounted) {
          setState(() {
            _busy = false;
            _checkingMemberId = null;
          });
        }
      }
    }
  }

  Future<void> _remark(SessionMember member) async {
    if (_busy || _session?.canEdit != true) {
      _message('同步快照已锁定，本机记录只读。');
      return;
    }
    setState(() => _busy = true);
    try {
      await showEditRemarkSheet(
        context: context,
        memberName: member.memberName,
        statusLabel: attendanceStatusLabels[member.status] ?? '未签到',
        initialRemark: member.remark,
        onSave: (text) =>
            widget.local.saveRemark(widget.sessionId, member.id, text),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _load();
      }
    }
  }

  Future<void> _end() async {
    if (_busy) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('结束本机签到'),
        content: const Text('未签到成员将记为缺勤，不能再签到。不会自动上传。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('结束任务'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.local.closeSession(widget.sessionId);
      _message('任务已在本机结束，可返回列表手动同步。');
    } on Object catch (_) {
      _message('结束未保存，请刷新后重试。');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    final filtered = _members
        .where(
          (m) =>
              (_keyword.isEmpty ||
                  m.memberName.contains(_keyword) ||
                  m.studentId.contains(_keyword)) &&
              (_filter == 'all' || m.status == _filter),
        )
        .toList();
    return Scaffold(
      body: SafeArea(
        child: CheckinFeedback(
          sequence: _successSequence,
          message: _successMessage,
          child: _error != null
              ? Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: BackButton(),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: ErrorState(
                          title: '本机任务读取失败',
                          message: _error!,
                          retrying: false,
                          onRetry: _load,
                        ),
                      ),
                    ),
                  ],
                )
              : s == null
              ? const LoadingSkeleton(fullPage: true, attendance: true)
              : AttendanceWorkspace(
                  session: s.session,
                  members: _members,
                  filteredMembers: filtered,
                  ended: s.isClosed,
                  local: true,
                  notice: s.locked
                      ? '已进入同步流程，本机快照只读；失败可返回手动重试。'
                      : '不会自动上传，任务结束后请返回列表手动同步。',
                  endAction: s.isClosed
                      ? null
                      : OutlinedButton(
                          onPressed: _busy ? null : _end,
                          child: const Text('结束本机任务'),
                        ),
                  searchController: _searchController,
                  statusFilter: _filter,
                  onSearchChanged: (value) =>
                      setState(() => _keyword = value.trim()),
                  onStatusChanged: (value) => setState(() => _filter = value),
                  onRefresh: _load,
                  memberBuilder: (member) => MemberCard(
                    member: member,
                    checking: _checkingMemberId == member.id,
                    enabled: !_busy,
                    onCheckin: s.isClosed || !s.canEdit
                        ? null
                        : () => _checkin(member),
                    onEditRemark: () => _remark(member),
                  ),
                ),
        ),
      ),
    );
  }
}
