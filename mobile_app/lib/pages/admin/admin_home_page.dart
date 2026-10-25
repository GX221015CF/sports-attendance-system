import 'package:flutter/material.dart';

import '../../services/admin_auth_service.dart';
import '../../services/admin_dashboard_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/adaptive_page_body.dart';
import '../../widgets/attendance_motion.dart';
import 'admin_create_session_page.dart';
import 'admin_groups_page.dart';
import 'admin_members_page.dart';
import 'admin_sessions_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key, this.dashboardService, this.authService});
  final AdminDashboardService? dashboardService;
  final AdminAuthService? authService;

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  late final _authService = widget.authService ?? AdminAuthService();
  late final _dashboardService =
      widget.dashboardService ?? AdminDashboardService();

  bool _loading = false;
  bool _signingOut = false;
  String? _errorMessage;
  AdminDashboardStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final stats = await _dashboardService.fetchDashboardStats();

      if (!mounted) {
        return;
      }

      setState(() {
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

  Future<void> _handleSignOut() async {
    if (_signingOut) {
      return;
    }

    setState(() {
      _signingOut = true;
    });

    try {
      await _authService.signOut();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已退出管理员登录')));

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on Object catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('退出登录失败，请稍后重试')));
    } finally {
      if (mounted) {
        setState(() {
          _signingOut = false;
        });
      }
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('功能将在下一步实现')));
  }

  Future<void> _openMembersPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AdminMembersPage()));
    await _loadStats();
  }

  Future<void> _openGroupsPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AdminGroupsPage()));
    await _loadStats();
  }

  Future<void> _openCreateSessionPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AdminCreateSessionPage()));
    await _loadStats();
  }

  Future<void> _openSessionsPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AdminSessionsPage()));
    await _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final email = _authService.currentUser?.email ?? '管理员';
    final cards = [
      _AdminFeature(
        title: '成员管理',
        description: '查看、维护队员信息',
        icon: Icons.groups_2_outlined,
        onTap: _openMembersPage,
      ),
      _AdminFeature(
        title: '分组管理',
        description: '维护训练分组和描述',
        icon: Icons.category_outlined,
        onTap: _openGroupsPage,
      ),
      _AdminFeature(
        title: '签到任务',
        description: '查看签到进度和结果',
        icon: Icons.fact_check_outlined,
        onTap: _openSessionsPage,
      ),
      _AdminFeature(
        title: '数据导出',
        description: '电脑 Web 后台使用',
        icon: Icons.file_download_outlined,
        onTap: _showComingSoon,
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: AdaptivePageBody(
          storageKey: 'admin-home',
          toolbar: _TopBar(
            loading: _loading,
            signingOut: _signingOut,
            onRefresh: _loadStats,
            onSignOut: _handleSignOut,
          ),
          summary: _AdminHero(email: email),
          onRefresh: _loadStats,
          slivers: [
            SliverToBoxAdapter(
              child: _loading && _stats == null
                  ? const LoadingSkeleton(statistics: true, cardHeight: 82)
                  : _errorMessage != null
                  ? _DashboardError(retrying: _loading, onRetry: _loadStats)
                  : _DashboardGrid(stats: _stats ?? _emptyStats),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  '常用功能',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            ResponsiveSliverCards(
              itemCount: cards.length,
              minCardWidth: 220,
              maxColumns: 3,
              itemBuilder: (context, index) =>
                  _FeatureCard(feature: cards[index]),
            ),
          ],
          footer: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openCreateSessionPage,
              icon: const Icon(Icons.add_task_outlined),
              label: const Text('创建签到'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _emptyStats = AdminDashboardStats(
  activeMembers: 0,
  groups: 0,
  activeSessions: 0,
  closedSessions: 0,
  pendingCheckins: 0,
  lateCheckins: 0,
);

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.loading,
    required this.signingOut,
    required this.onRefresh,
    required this.onSignOut,
  });

  final bool loading;
  final bool signingOut;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;

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
              '管理员中心',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textStrong,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.refresh, color: AppTheme.primary),
          ),
          TextButton.icon(
            onPressed: signingOut ? null : onSignOut,
            icon: signingOut
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            label: const Text('退出'),
          ),
        ],
      ),
    );
  }
}

class _AdminHero extends StatelessWidget {
  const _AdminHero({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.dashboard_customize_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '数据看板',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({required this.stats});

  final AdminDashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      _DashboardItem(
        '成员总数',
        stats.activeMembers,
        AppTheme.primary,
        Icons.groups,
      ),
      _DashboardItem('分组数量', stats.groups, AppTheme.textMuted, Icons.category),
      _DashboardItem(
        '进行中签到',
        stats.activeSessions,
        AppTheme.success,
        Icons.play_circle_outline,
      ),
      _DashboardItem(
        '已结束签到',
        stats.closedSessions,
        AppTheme.textMuted,
        Icons.lock_clock_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final item in items)
            SizedBox(
              width: constraints.maxWidth >= 420
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth,
              child: _DashboardCard(item: item),
            ),
        ],
      ),
    );
  }
}

class _DashboardItem {
  const _DashboardItem(this.label, this.value, this.color, this.icon);

  final String label;
  final int value;
  final Color color;
  final IconData icon;
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.item});

  final _DashboardItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: item.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RollingCount(
                    value: item.value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: item.color,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w800,
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

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.retrying, required this.onRetry});

  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppTheme.error, size: 42),
          const SizedBox(height: 10),
          Text(
            '数据看板加载失败',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textStrong,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '请检查网络连接后重试。',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: retrying ? null : onRetry,
            icon: retrying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(retrying ? '重试中...' : '重试'),
          ),
        ],
      ),
    );
  }
}

class _AdminFeature {
  const _AdminFeature({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});

  final _AdminFeature feature;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: feature.onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(feature.icon, color: AppTheme.primary),
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    feature.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textStrong,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    feature.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
