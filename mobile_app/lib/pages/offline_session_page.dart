import 'package:flutter/material.dart';

import '../models/offline_session.dart';
import '../models/session_member.dart';
import '../services/offline_attendance_service.dart';
import '../services/time_service.dart';
import '../widgets/checkin_confirm_dialog.dart';
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
  String _keyword = '';
  String _filter = 'all';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
    if (_busy || s == null || s.isClosed || !s.canEdit) return;
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final preview = TimeService().previewCheckin(
        now: now,
        requiredTime: s.session.requiredTime,
        endTime: s.session.endTime,
      );
      final approved = await showDialog<bool>(
        context: context,
        builder: (_) =>
            CheckinConfirmDialog(member: member, now: now, preview: preview),
      );
      if (approved != true || !mounted) return;
      // The service rechecks time at confirmation, rather than dialog opening.
      final saved = await widget.local.checkin(widget.sessionId, member.id);
      _message(
        saved.status == 'late'
            ? '已保存在本机，迟到 ${saved.lateMinutes} 分钟'
            : '正常签到已保存在本机，尚未上传',
      );
    } on Object catch (_) {
      _message('签到未保存：可能已签到、已截止或本地写入失败，请刷新确认。');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _load();
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
        statusLabel: member.status,
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
    final checked = _members
        .where((m) => m.status == 'normal' || m.status == 'late')
        .length;
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
      appBar: AppBar(title: Text(s?.session.title ?? '本机离线签到')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            const Text('离线签到 · 数据仅保存在本机'),
            if (s == null && _error == null) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            if (s != null) ...[
              Text(s.isClosed ? '任务已结束' : '任务进行中'),
              if (s.locked) const Text('已进入同步流程，本机快照只读；失败可返回手动重试。'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(label: Text('参与 ${_members.length}')),
                  Chip(label: Text('已签 $checked')),
                  for (final entry in const {
                    'pending': '未签',
                    'normal': '正常',
                    'late': '迟到',
                    'absent': '缺勤',
                  }.entries)
                    Chip(
                      label: Text(
                        '${entry.value} ${_members.where((m) => m.status == entry.key).length}',
                      ),
                    ),
                  Chip(
                    label: Text(
                      '出勤率 ${_members.isEmpty ? '0' : (checked * 100 / _members.length).toStringAsFixed(1)}%',
                    ),
                  ),
                ],
              ),
              if (!s.isClosed)
                OutlinedButton(
                  onPressed: _busy ? null : _end,
                  child: const Text('结束本机任务'),
                ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  hintText: '搜索姓名或学号',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _keyword = v.trim()),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: _filter,
                isExpanded: true,
                items:
                    const {
                          'all': '全部状态',
                          'pending': '未签到',
                          'normal': '正常',
                          'late': '迟到',
                          'absent': '缺勤',
                        }.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _filter = v ?? 'all'),
              ),
              for (final m in filtered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MemberCard(
                    member: m,
                    checking: _busy,
                    onCheckin: _busy || s.isClosed || !s.canEdit
                        ? null
                        : () => _checkin(m),
                    onEditRemark: () => _remark(m),
                  ),
                ),
              if (filtered.isEmpty) const Text('没有匹配成员。'),
            ],
          ],
        ),
      ),
    );
  }
}
