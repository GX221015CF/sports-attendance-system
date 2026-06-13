import 'package:flutter/material.dart';

import '../models/session_member.dart';
import '../services/time_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import 'status_tag.dart';

class CheckinConfirmDialog extends StatelessWidget {
  const CheckinConfirmDialog({
    super.key,
    required this.member,
    required this.now,
    required this.preview,
  });

  final SessionMember member;
  final DateTime now;
  final CheckinPreview preview;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 34, 24, 30),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fact_check_outlined,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '签到确认',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '请核对运动员签到信息',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
              child: Column(
                children: [
                  Text(
                    '运动员姓名',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    member.memberName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.textStrong,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _DialogMetric(
                          icon: Icons.schedule,
                          label: '当前时间',
                          value: formatDateTime(now).substring(11),
                          color: AppTheme.primary,
                        ),
                      ),
                      Expanded(child: _StatusMetric(preview: preview)),
                    ],
                  ),
                  if (preview.lateMinutes > 0) ...[
                    const SizedBox(height: 16),
                    Text(
                      '迟到 ${preview.lateMinutes} 分钟',
                      style: const TextStyle(
                        color: AppTheme.error,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Divider(height: 1),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFE5E7EB),
                            foregroundColor: AppTheme.textMuted,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: preview.canCheckin
                              ? () => Navigator.of(context).pop(true)
                              : null,
                          child: const Text('确认签到'),
                        ),
                      ),
                    ],
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

class _DialogMetric extends StatelessWidget {
  const _DialogMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textStrong,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusMetric extends StatelessWidget {
  const _StatusMetric({required this.preview});

  final CheckinPreview preview;

  @override
  Widget build(BuildContext context) {
    final color = preview.status == 'late'
        ? AppTheme.secondary
        : preview.canCheckin
        ? AppTheme.success
        : AppTheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '预测状态',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              preview.canCheckin
                  ? Icons.check_circle_outline
                  : Icons.event_busy_outlined,
              color: color,
              size: 24,
            ),
            const SizedBox(width: 8),
            StatusTag(status: preview.status),
          ],
        ),
      ],
    );
  }
}
