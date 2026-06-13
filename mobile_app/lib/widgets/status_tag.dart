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
      'late' => AppTheme.error,
      'absent' => Colors.deepOrange,
      'closed' => Colors.deepOrange,
      'active' => AppTheme.success,
      _ => Colors.blueGrey,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        border: Border.all(color: _color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
