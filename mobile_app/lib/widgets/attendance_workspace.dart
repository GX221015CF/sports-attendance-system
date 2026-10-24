import 'package:flutter/material.dart';

import '../models/attendance_session.dart';
import '../models/session_member.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import 'empty_state.dart';

const attendanceStatusLabels = {
  'all': '全部',
  'pending': '未签到',
  'normal': '正常',
  'late': '迟到',
  'absent': '缺勤',
};

/// Shared presentation only; online and local services keep their own rules.
class AttendanceWorkspace extends StatelessWidget {
  const AttendanceWorkspace({
    super.key,
    required this.session,
    required this.members,
    required this.filteredMembers,
    required this.ended,
    required this.local,
    required this.searchController,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onRefresh,
    required this.memberBuilder,
    this.loading = false,
    this.notice,
    this.endAction,
  });

  final AttendanceSession session;
  final List<SessionMember> members;
  final List<SessionMember> filteredMembers;
  final bool ended;
  final bool local;
  final TextEditingController searchController;
  final String statusFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final Future<void> Function() onRefresh;
  final Widget Function(SessionMember) memberBuilder;
  final bool loading;
  final String? notice;
  final Widget? endAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Height changes while the keyboard animates must not change columns.
        final wide = constraints.maxWidth >= 760;
        final overview = _Overview(
          session: session,
          members: members,
          ended: ended,
          local: local,
          notice: notice,
          endAction: endAction,
        );
        final search = _SearchAndFilters(
          controller: searchController,
          hint: local ? '搜索姓名或学号' : '按姓名搜索',
          status: statusFilter,
          onSearch: onSearchChanged,
          onStatus: onStatusChanged,
        );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    BackButton(color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                  ],
                ),
              ),
              if (loading) const LinearProgressIndicator(),
              Expanded(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: constraints.maxWidth >= 1000 ? 280 : 240,
                            child: ListView(
                              key: const PageStorageKey('attendance-overview'),
                              padding: const EdgeInsets.only(
                                top: 8,
                                bottom: 20,
                              ),
                              children: [overview],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              children: [
                                search,
                                const SizedBox(height: 12),
                                Expanded(child: _roster()),
                              ],
                            ),
                          ),
                        ],
                      )
                    : _roster(
                        header: Column(
                          children: [
                            overview,
                            const SizedBox(height: 16),
                            search,
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _roster({Widget? header}) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        key: const PageStorageKey('attendance-roster'),
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          if (header != null) SliverToBoxAdapter(child: header),
          if (filteredMembers.isEmpty)
            const SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.search_off,
                title: '没有匹配成员',
                message: '请调整搜索内容或切换签到状态。',
              ),
            )
          else
            SliverLayoutBuilder(
              builder: (context, constraints) {
                final largeText =
                    MediaQuery.textScalerOf(context).scale(16) > 22;
                final columns = constraints.crossAxisExtent >= 720 && !largeText
                    ? 2
                    : 1;
                // Natural row heights accommodate notes, metadata and large text.
                // Only rows near the viewport are built.
                return SliverList.builder(
                  itemCount: (filteredMembers.length / columns).ceil(),
                  itemBuilder: (context, row) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var column = 0; column < columns; column++) ...[
                          if (column > 0) const SizedBox(width: 12),
                          Expanded(
                            child:
                                row * columns + column < filteredMembers.length
                                ? KeyedSubtree(
                                    key: ValueKey(
                                      filteredMembers[row * columns + column]
                                          .id,
                                    ),
                                    child: memberBuilder(
                                      filteredMembers[row * columns + column],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.hint,
    required this.status,
    required this.onSearch,
    required this.onStatus,
  });
  final TextEditingController controller;
  final String hint;
  final String status;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onSearch,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in attendanceStatusLabels.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: status == entry.key,
                    onSelected: (_) => onStatus(entry.key),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.session,
    required this.members,
    required this.ended,
    required this.local,
    this.notice,
    this.endAction,
  });
  final AttendanceSession session;
  final List<SessionMember> members;
  final bool ended;
  final bool local;
  final String? notice;
  final Widget? endAction;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{
      for (final key in attendanceStatusLabels.keys) key: 0,
    };
    for (final member in members) {
      counts.update(member.status, (count) => count + 1, ifAbsent: () => 1);
    }
    final checked = counts['normal']! + counts['late']!;
    final rate = members.isEmpty ? 0.0 : checked / members.length;
    final stats = {
      '参与': members.length.toString(),
      '已签': checked.toString(),
      '未签': counts['pending'].toString(),
      '正常': counts['normal'].toString(),
      '迟到': counts['late'].toString(),
      '缺勤': counts['absent'].toString(),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ended ? '任务已结束' : '任务进行中',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                local ? '离线签到 · 数据仅保存在本机' : '在线签到 · 数据保存至云端',
                style: const TextStyle(color: Color(0xFFE0E7FF)),
              ),
              const SizedBox(height: 16),
              Text(
                '规定签到\n${formatDateTime(session.requiredTime)}',
                style: const TextStyle(color: Colors.white, height: 1.5),
              ),
              const SizedBox(height: 10),
              Text(
                '结束时间\n${formatDateTime(session.endTime)}',
                style: const TextStyle(color: Colors.white, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '出勤率 ${(rate * 100).toStringAsFixed(1)}%',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: rate,
          minHeight: 6,
          borderRadius: BorderRadius.circular(8),
          color: AppTheme.secondary,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in stats.entries)
                SizedBox(
                  width: (constraints.maxWidth - 8) / 2,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.value,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        Text(
                          entry.key,
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (notice != null || ended) ...[
          const SizedBox(height: 12),
          Text(
            notice ?? '本次签到已结束，不能继续签到。',
            style: const TextStyle(color: AppTheme.textMuted, height: 1.5),
          ),
        ],
        if (endAction != null) ...[const SizedBox(height: 16), endAction!],
      ],
    );
  }
}
