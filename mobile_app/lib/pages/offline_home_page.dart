import 'package:flutter/material.dart';
import '../widgets/attendance_motion.dart';
import '../widgets/interaction_audio_controls.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/offline_session.dart';
import '../services/admin_session_service.dart';
import '../services/offline_attendance_service.dart';
import '../services/offline_sync_service.dart';
import '../utils/date_formatter.dart';
import '../widgets/adaptive_page_body.dart';
import 'admin/admin_create_session_page.dart';
import 'admin/admin_login_page.dart';
import 'offline_session_page.dart';

class OfflineHomePage extends StatefulWidget {
  const OfflineHomePage({
    super.key,
    required this.local,
    required this.onGoOnline,
  });
  final OfflineAttendanceService local;
  final VoidCallback onGoOnline;

  @override
  State<OfflineHomePage> createState() => _OfflineHomePageState();
}

class _OfflineHomePageState extends State<OfflineHomePage> {
  List<OfflineSession> _sessions = [];
  OfflineRoster? _roster;
  bool _loading = true;
  bool _preparing = false;
  String? _syncingId;
  String? _error;
  OfflineSyncService? _sync;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final roster = await widget.local.getRoster();
      final sessions = await widget.local.listSessions();
      for (final s in sessions) {
        await widget.local.closeSession(s.session.id, onlyIfExpired: true);
      }
      final current = await widget.local.listSessions();
      if (mounted) {
        setState(() {
          _roster = roster;
          _sessions = current;
          _error = null;
          _loading = false;
        });
      }
    } on Object catch (_) {
      if (mounted) {
        setState(() {
          _error = '本机记录读取失败，请重试；不要清除应用数据。';
          _loading = false;
        });
      }
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<bool> _ensureLogin() async {
    if (!hasSupabaseConfig) {
      _message('未配置线上服务，不能准备名单或同步。');
      return false;
    }
    if (Supabase.instance.client.auth.currentUser == null) {
      await Navigator.of(context).push(
        MaterialPageRoute<bool>(
          builder: (_) => const AdminLoginPage(returnAfterLogin: true),
        ),
      );
      if (!mounted) return false;
    }
    return Supabase.instance.client.auth.currentUser != null;
  }

  Future<void> _prepareRoster() async {
    if (_preparing || _syncingId != null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('联网准备离线名单'),
        content: const Text(
          '此操作会读取云端成员与分组并保存到本机，不会上传离线任务。'
          '\n需要可访问服务的网络。更新名单不改变已经发布的本机任务。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('读取并保存'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted || !await _ensureLogin()) return;
    if (!mounted) return;
    setState(() => _preparing = true);
    try {
      final client = Supabase.instance.client;
      final user = (await client.auth.getUser().timeout(
        const Duration(seconds: 20),
      )).user;
      if (user == null) throw StateError('请先登录。');
      final remote = AdminSessionService(client: client);
      final groups = await remote.fetchGroups().timeout(
        const Duration(seconds: 20),
      );
      final members = await remote.fetchActiveMembers().timeout(
        const Duration(seconds: 20),
      );
      if (client.auth.currentUser?.id != user.id) {
        throw StateError('帐号已变化，请重新准备名单。');
      }
      await widget.local.saveRoster(
        ownerId: user.id,
        groups: groups,
        members: members,
      );
      _message('名单已保存到本机；离线任务不会自动同步。');
      await _load();
    } on Object catch (_) {
      _message('名单准备失败，原有名单已保留。请检查服务连接和管理员登录。');
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _create() async {
    final roster = _roster;
    if (roster == null || roster.members.isEmpty) {
      _message('请先联网准备有效成员名单。');
      return;
    }
    if (hasSupabaseConfig &&
        Supabase.instance.client.auth.currentUser?.id != roster.ownerId) {
      _message('请使用准备名单时的帐号登录，或重新准备名单。');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => AdminCreateSessionPage(
          isOffline: true,
          loadGroups: () async => roster.groups,
          loadMembers: () async => roster.members,
          publish: widget.local.createSession,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _upload(OfflineSession s) async {
    if (_syncingId != null || !s.canSync) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('手动同步已结束任务'),
        content: Text(
          '将上传“${s.session.title}”的完整最终结果。'
          '\n首次同步会锁定本机快照，失败可重试，但不能再修改本机备注。'
          '\n不会上传其他任务，也不会按上传时间重算签到。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('确认同步'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted || !await _ensureLogin()) return;
    if (!mounted) return;
    setState(() => _syncingId = s.session.id);
    try {
      final client = Supabase.instance.client;
      final user = (await client.auth.getUser().timeout(
        const Duration(seconds: 20),
      )).user;
      if (user == null || user.id != s.ownerId) {
        _message('请使用准备此任务名单时的帐号同步。');
        return;
      }
      _sync ??= OfflineSyncService(
        widget.local,
        SupabaseOfflineUploader(client),
      );
      await _sync!.sync(s.session.id, ownerId: user.id);
      _message('整单同步成功，可以在 Web 历史任务中查看。');
    } on Object catch (_) {
      _message('同步未确认成功，本机记录已保留。请检查网络、登录或同步接口后重试。');
    } finally {
      if (mounted) {
        setState(() => _syncingId = null);
        await _load();
      }
    }
  }

  String _syncLabel(OfflineSession s) => switch (s.syncState) {
    'synced' => '已同步 · 本机只读',
    'failed' => '同步失败 · 可手动重试',
    'syncing' => '上次同步未确认 · 可手动重试',
    _ => s.isClosed ? '已结束 · 待手动同步' : '进行中 · 仅保存在本机',
  };

  Widget _sessionCard(OfflineSession s, bool busy) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.session.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('规定：${formatDateTime(s.session.requiredTime)}'),
            Text('结束：${formatDateTime(s.session.endTime)}'),
            Text(
              _syncLabel(s),
              style: const TextStyle(
                color: Colors.deepOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (s.lastError != null) Text(s.lastError!),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => OfflineSessionPage(
                                local: widget.local,
                                sessionId: s.session.id,
                              ),
                            ),
                          );
                          if (mounted) await _load();
                        },
                  child: Text(s.isClosed ? '查看结果与备注' : '进入签到'),
                ),
                if (s.canSync)
                  FilledButton.icon(
                    onPressed: busy ? null : () => _upload(s),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(_syncingId == s.session.id ? '同步中…' : '手动同步'),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final busy = _preparing || _syncingId != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('离线模式'),
        actions: [
          const SoundToggleButton(color: Colors.white),
          TextButton(
            onPressed: busy ? null : widget.onGoOnline,
            child: const Text('切回在线', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SafeArea(
        child: AdaptivePageBody(
          storageKey: 'offline-home',
          toolbar: const SizedBox.shrink(),
          onRefresh: _load,
          summary: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '仅操作本机新建任务 · 不自动同步',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('联网、切换模式和重启都不会上传。进行中的任务不能同步。'),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _roster == null
                            ? '尚未准备离线名单'
                            : '已保存 ${_roster!.members.length} 名成员 · ${formatDateTime(_roster!.savedAt)}',
                      ),
                      const SizedBox(height: 8),
                      const Text('名单只读；手机系统时间用于离线签到，请保持正确。'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: busy ? null : _prepareRoster,
                        icon: const Icon(Icons.download_outlined),
                        label: Text(_preparing ? '准备中…' : '联网准备名单'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: busy || _loading ? null : _create,
                        icon: const Icon(Icons.add),
                        label: const Text('创建离线签到'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          slivers: [
            if (_loading)
              const SliverToBoxAdapter(child: LinearProgressIndicator()),
            if (_loading && _sessions.isEmpty)
              const SliverToBoxAdapter(child: LoadingSkeleton()),
            if (_error != null) SliverToBoxAdapter(child: Text(_error!)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '本机任务 · ${_sessions.length}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            if (!_loading && _sessions.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('暂无本机离线任务。准备名单后即可创建并发布。'),
                ),
              ),
            ResponsiveSliverCards(
              itemCount: _sessions.length,
              itemBuilder: (context, index) =>
                  _sessionCard(_sessions[index], busy),
            ),
          ],
        ),
      ),
    );
  }
}
