import 'package:flutter/material.dart';

import '../config/supabase_config.dart';
import '../models/attendance_session.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/status_tag.dart';
import 'session_member_list_page.dart';

class CurrentSessionPage extends StatefulWidget {
  const CurrentSessionPage({super.key});

  @override
  State<CurrentSessionPage> createState() => _CurrentSessionPageState();
}

class _CurrentSessionPageState extends State<CurrentSessionPage> {
  final AttendanceService _attendanceService = AttendanceService();

  bool _loading = false;
  bool _autoCloseNotified = false;
  AttendanceSession? _session;
  Map<String, int> _stats = const {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    if (hasSupabaseConfig) {
      _loadCurrentSession();
    }
  }

  Future<void> _loadCurrentSession() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final session = await _attendanceService.getCurrentActiveSession();

      if (session != null) {
        final closed = await _attendanceService.closeExpiredSessionIfNeeded(
          session,
        );

        if (closed) {
          if (mounted && !_autoCloseNotified) {
            _autoCloseNotified = true;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('本次签到已结束，未签到成员已标记为缺勤')),
            );
          }

          final latestSession = await _attendanceService
              .getCurrentActiveSession();
          final latestStats = latestSession == null
              ? <String, int>{}
              : await _attendanceService.getSessionStats(latestSession.id);

          if (!mounted) {
            return;
          }

          setState(() {
            _session = latestSession;
            _stats = latestStats;
          });
          return;
        }
      }

      final stats = session == null
          ? <String, int>{}
          : await _attendanceService.getSessionStats(session.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _session = session;
        _stats = stats;
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

  void _openMemberList() {
    final session = _session;
    if (session == null) {
      return;
    }

    Navigator.of(context)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => SessionMemberListPage(session: session),
          ),
        )
        .then((_) => _loadCurrentSession());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: _buildBody(context)));
  }

  Widget _buildBody(BuildContext context) {
    if (!hasSupabaseConfig) {
      return const EmptyState(
        icon: Icons.settings_outlined,
        title: '未配置 Supabase',
        message: '请使用 --dart-define 或 .env 文件传入 Supabase 配置。',
      );
    }

    if (_loading && _session == null && _errorMessage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ErrorState(
        title: '读取失败',
        message: _errorMessage!,
        retrying: _loading,
        onRetry: _loadCurrentSession,
      );
    }

    if (_session == null) {
      return EmptyState(
        icon: Icons.directions_run_outlined,
        title: '当前暂无进行中的签到',
        message: '在管理员后台创建签到任务后，这里会显示今日签到信息。',
        action: ElevatedButton.icon(
          onPressed: _loading ? null : _loadCurrentSession,
          icon: const Icon(Icons.refresh),
          label: const Text('刷新'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCurrentSession,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const _HeroHeader(),
          const SizedBox(height: 16),
          _SessionCard(session: _session!),
          const SizedBox(height: 16),
          _StatsGrid(stats: _stats),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _loadCurrentSession,
                  icon: const Icon(Icons.refresh),
                  label: Text(_loading ? '刷新中...' : '刷新'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _openMemberList,
                  icon: const Icon(Icons.login),
                  label: const Text('进入签到'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, Color(0xFF2563EB), AppTheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '运动队签到',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '快速查看训练签到进度',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.86),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_run,
              color: Colors.white,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final AttendanceSession session;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textStrong,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const StatusTag(status: 'active'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TimeBox(
                    icon: Icons.schedule,
                    label: '规定签到',
                    value: formatDateTime(session.requiredTime),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeBox(
                    icon: Icons.flag_outlined,
                    label: '结束时间',
                    value: formatDateTime(session.endTime),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary, size: 22),
          const SizedBox(height: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final Map<String, int> stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem('参与', stats['total'] ?? 0, AppTheme.primary, Icons.groups),
      _StatItem('已签到', stats['checked'] ?? 0, AppTheme.success, Icons.done),
      _StatItem('未签到', stats['pending'] ?? 0, Colors.blueGrey, Icons.timer),
      _StatItem('迟到', stats['late'] ?? 0, AppTheme.secondary, Icons.warning),
      _StatItem('缺勤', stats['absent'] ?? 0, AppTheme.error, Icons.close),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.72,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _StatCard(item: item);
      },
    );
  }
}

class _StatItem {
  const _StatItem(this.label, this.value, this.color, this.icon);

  final String label;
  final int value;
  final Color color;
  final IconData icon;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});

  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: item.color.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.value}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: item.color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
