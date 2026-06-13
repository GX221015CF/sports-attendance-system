import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StatusTag extends StatelessWidget {
  const StatusTag({super.key, required this.status});

  final String status;

  String get _label {
    return switch (status) {
      'normal' => '正常',
      'late' => '迟到',
      'absent' => '缺勤',
      'closed' => '已结束',
      'active' => '进行中',
      _ => '未签到',
    };
  }

  Color get _color {
    return switch (status) {
      'normal' => AppTheme.success,
      'late' => AppTheme.secondary,
      'absent' => const Color(0xFFB91C1C),
      'closed' => Colors.deepOrange,
      'active' => AppTheme.primary,
      _ => Colors.blueGrey,
    };
  }

  Color get _background {
    return switch (status) {
      'normal' => const Color(0xFFEAF8F0),
      'late' => const Color(0xFFFFEFE5),
      'absent' => const Color(0xFFFEE2E2),
      'closed' => const Color(0xFFFFEFE5),
      'active' => const Color(0xFFE8ECF8),
      _ => const Color(0xFFE5E7EB),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'active') ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            _label,
            style: TextStyle(
              color: _color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
