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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('确认签到'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroStatus(preview: preview),
          const SizedBox(height: 16),
          _DialogRow(label: '成员', value: member.memberName),
          const SizedBox(height: 10),
          _DialogRow(label: '当前时间', value: formatDateTime(now)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('预计状态：'),
              StatusTag(status: preview.status),
            ],
          ),
          if (preview.lateMinutes > 0) ...[
            const SizedBox(height: 10),
            Text(
              '迟到 ${preview.lateMinutes} 分钟',
              style: const TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: preview.canCheckin
              ? () => Navigator.of(context).pop(true)
              : null,
          child: const Text('确认签到'),
        ),
      ],
    );
  }
}

class _HeroStatus extends StatelessWidget {
  const _HeroStatus({required this.preview});

  final CheckinPreview preview;

  @override
  Widget build(BuildContext context) {
    final color = preview.status == 'late'
        ? AppTheme.error
        : preview.canCheckin
        ? AppTheme.success
        : Colors.deepOrange;
    final icon = preview.canCheckin
        ? Icons.check_circle_outline
        : Icons.event_busy_outlined;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              preview.message,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogRow extends StatelessWidget {
  const _DialogRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label：', style: const TextStyle(color: AppTheme.textMuted)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
