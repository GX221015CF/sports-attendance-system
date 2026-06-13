import 'package:flutter/material.dart';

import '../config/supabase_config.dart';
import '../models/attendance_session.dart';
import '../services/admin_auth_service.dart';
import '../services/attendance_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/status_tag.dart';
import 'admin/admin_home_page.dart';
import 'admin/admin_login_page.dart';
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

  void _openAdminEntry() {
    final adminAuthService = AdminAuthService();
    final page = adminAuthService.isSignedIn
        ? const AdminHomePage()
        : const AdminLoginPage();

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: SafeArea(child: _buildBody(context)));
  }

  Widget _buildBody(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape =
            constraints.maxWidth > constraints.maxHeight ||
            constraints.maxWidth >= 720;
        final padding = isLandscape
            ? const EdgeInsets.fromLTRB(18, 0, 18, 18)
            : const EdgeInsets.fromLTRB(22, 0, 22, 24);

        return RefreshIndicator(
          onRefresh: _loadCurrentSession,
          child: ListView(
            padding: padding,
            children: [
              _TopBar(compact: isLandscape, onAdminPressed: _openAdminEntry),
              SizedBox(height: isLandscape ? 8 : 12),
              _CurrentSessionContent(
                hasConfig: hasSupabaseConfig,
                loading: _loading,
                errorMessage: _errorMessage,
                session: _session,
                stats: _stats,
                compact: isLandscape,
                onRefresh: _loadCurrentSession,
                onEnterMembers: _openMemberList,
                onAdminPressed: _openAdminEntry,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CurrentSessionContent extends StatelessWidget {
  const _CurrentSessionContent({
    required this.hasConfig,
    required this.loading,
    required this.errorMessage,
    required this.session,
    required this.stats,
    required this.compact,
    required this.onRefresh,
    required this.onEnterMembers,
    required this.onAdminPressed,
  });

  final bool hasConfig;
  final bool loading;
  final String? errorMessage;
  final AttendanceSession? session;
  final Map<String, int> stats;
  final bool compact;
  final VoidCallback onRefresh;
  final VoidCallback onEnterMembers;
  final VoidCallback onAdminPressed;

  @override
  Widget build(BuildContext context) {
    if (!hasConfig) {
      return const EmptyState(
        icon: Icons.settings_outlined,
        title: '未配置 Supabase',
        message: '请使用 --dart-define 或 .env 文件传入 Supabase 配置。',
      );
    }

    if (loading && session == null && errorMessage == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 120),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Column(
        children: [
          ErrorState(
            title: '数据加载失败',
            message: '当前签到读取失败，请检查网络连接后重试。',
            retrying: loading,
            onRetry: onRefresh,
          ),
          _AdminHintCard(onAdminPressed: onAdminPressed),
        ],
      );
    }

    final activeSession = session;
    if (activeSession == null) {
      return Column(
        children: [
          EmptyState(
            icon: Icons.event_busy_outlined,
            title: '当前暂无进行中的签到',
            message: '所有训练或比赛签到都已结束，或管理员尚未创建新的签到。',
            action: ElevatedButton.icon(
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新'),
            ),
          ),
          _AdminHintCard(onAdminPressed: onAdminPressed),
        ],
      );
    }

    if (compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _HeroCard(
              session: activeSession,
              compact: true,
              onRefresh: onRefresh,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _TaskPanel(
              session: activeSession,
              stats: stats,
              loading: loading,
              compact: true,
              onRefresh: onRefresh,
              onEnter: onEnterMembers,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _HeroCard(session: activeSession, compact: false, onRefresh: onRefresh),
        const SizedBox(height: 14),
        _TaskPanel(
          session: activeSession,
          stats: stats,
          loading: loading,
          compact: false,
          onRefresh: onRefresh,
          onEnter: onEnterMembers,
        ),
      ],
    );
  }
}

class _AdminHintCard extends StatelessWidget {
  const _AdminHintCard({required this.onAdminPressed});

  final VoidCallback onAdminPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.admin_panel_settings_outlined,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '管理员可进入后台创建新的签到或管理成员。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(onPressed: onAdminPressed, child: const Text('管理员')),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.compact, required this.onAdminPressed});

  final bool compact;
  final VoidCallback onAdminPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 52 : 64,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.directions_run, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '今日签到',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.textStrong,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            formatDateTime(DateTime.now()).substring(5, 10),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: '管理员',
            onPressed: onAdminPressed,
            icon: const Icon(
              Icons.admin_panel_settings_outlined,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.session,
    required this.compact,
    required this.onRefresh,
  });

  final AttendanceSession session;
  final bool compact;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 18 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -28,
            child: Icon(
              Icons.fitness_center,
              size: compact ? 112 : 150,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const StatusTag(status: 'normal'),
                  const Spacer(),
                  IconButton(
                    tooltip: '刷新',
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                  ),
                ],
              ),
              SizedBox(height: compact ? 8 : 18),
              Text(
                session.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 28 : 36,
                ),
              ),
              SizedBox(height: compact ? 12 : 20),
              _HeroTimeRow(
                icon: Icons.schedule,
                label: '规定签到',
                value: formatDateTime(session.requiredTime),
              ),
              const SizedBox(height: 8),
              _HeroTimeRow(
                icon: Icons.alarm_off_outlined,
                label: '结束时间',
                value: formatDateTime(session.endTime),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroTimeRow extends StatelessWidget {
  const _HeroTimeRow({
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
        Icon(icon, color: Colors.white.withValues(alpha: 0.88), size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.76),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
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

class _TaskPanel extends StatelessWidget {
  const _TaskPanel({
    required this.session,
    required this.stats,
    required this.loading,
    required this.compact,
    required this.onRefresh,
    required this.onEnter,
  });

  final AttendanceSession session;
  final Map<String, int> stats;
  final bool loading;
  final bool compact;
  final VoidCallback onRefresh;
  final VoidCallback onEnter;

  int get total => stats['total'] ?? 0;
  int get checked => stats['checked'] ?? 0;
  int get pending => stats['pending'] ?? 0;
  int get normal => stats['normal'] ?? 0;
  int get late => stats['late'] ?? 0;
  int get absent => stats['absent'] ?? 0;
  double get completion => total == 0 ? 0 : checked / total;

  @override
  Widget build(BuildContext context) {
    final rateText = '${(completion * 100).toStringAsFixed(0)}%';

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '签到总览',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textStrong,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              _RateBadge(rateText: rateText),
            ],
          ),
          SizedBox(height: compact ? 12 : 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 9,
              value: completion.clamp(0, 1).toDouble(),
              backgroundColor: const Color(0xFFE2E8F0),
              color: AppTheme.secondary,
            ),
          ),
          SizedBox(height: compact ? 12 : 16),
          _StatGrid(
            compact: compact,
            items: [
              _StatItem('参与', total, AppTheme.primary),
              _StatItem('已签', checked, AppTheme.success),
              _StatItem('未签', pending, AppTheme.textMuted),
              _StatItem('正常', normal, AppTheme.success),
              _StatItem('迟到', late, AppTheme.secondary),
              _StatItem('缺勤', absent, const Color(0xFFB91C1C)),
            ],
          ),
          SizedBox(height: compact ? 12 : 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: loading ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onEnter,
                  icon: const Icon(Icons.login),
                  label: const Text('进入签到'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RateBadge extends StatelessWidget {
  const _RateBadge({required this.rateText});

  final String rateText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
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

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items, required this.compact});

  final List<_StatItem> items;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: compact ? 3 : 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: compact ? 72 : 76,
      ),
      itemBuilder: (context, index) => _StatTile(item: items[index]),
    );
  }
}

class _StatItem {
  const _StatItem(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.item});

  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: item.color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 28,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                item.value.toString(),
                maxLines: 1,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: item.color,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}
