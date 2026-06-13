import 'package:flutter/material.dart';

import '../models/session_member.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import 'status_tag.dart';

class MemberCard extends StatelessWidget {
  const MemberCard({
    super.key,
    required this.member,
    required this.onCheckin,
    required this.checking,
  });

  final SessionMember member;
  final VoidCallback? onCheckin;
  final bool checking;

  bool get _isLate => member.status == 'late' || member.lateMinutes > 0;
  bool get _isAbsent => member.status == 'absent';
  bool get _showCheckinButton =>
      member.status == 'pending' && onCheckin != null;

  Color get _accentColor {
    if (_isLate) {
      return AppTheme.error;
    }
    if (_isAbsent) {
      return Colors.deepOrange;
    }
    if (member.status == 'normal') {
      return AppTheme.success;
    }
    return AppTheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _isLate
            ? AppTheme.error.withValues(alpha: 0.04)
            : _isAbsent
            ? Colors.deepOrange.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accentColor.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 5, color: _accentColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _accentColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                member.memberName.isEmpty
                                    ? '?'
                                    : member.memberName.characters.first,
                                style: TextStyle(
                                  color: _accentColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.memberName,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: AppTheme.textStrong,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${member.groupName} · ${member.studentId}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          StatusTag(status: member.status),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoPill(
                              icon: Icons.access_time,
                              text: member.checkinTime == null
                                  ? '暂未签到'
                                  : formatDateTime(member.checkinTime!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _LatePill(minutes: member.lateMinutes),
                        ],
                      ),
                      if (_showCheckinButton) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: checking ? null : onCheckin,
                            icon: checking
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text(checking ? '签到中...' : '签到'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textStrong),
            ),
          ),
        ],
      ),
    );
  }
}

class _LatePill extends StatelessWidget {
  const _LatePill({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    final late = minutes > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: late
            ? AppTheme.error.withValues(alpha: 0.08)
            : AppTheme.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        late ? '迟到 $minutes 分钟' : '-',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: late ? AppTheme.error : AppTheme.textMuted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
