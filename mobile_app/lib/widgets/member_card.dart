import 'package:flutter/material.dart';

import '../models/session_member.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import 'status_tag.dart';
import 'form_surface.dart';
import 'attendance_motion.dart';

class MemberCard extends StatelessWidget {
  const MemberCard({
    super.key,
    required this.member,
    required this.onCheckin,
    required this.onEditRemark,
    required this.checking,
    this.enabled = true,
  });

  final SessionMember member;
  final VoidCallback? onCheckin;
  final VoidCallback onEditRemark;
  final bool checking;
  final bool enabled;

  bool get _showCheckinButton =>
      member.status == 'pending' && onCheckin != null;

  Color get _accentColor {
    return switch (member.status) {
      'normal' => AppTheme.success,
      'late' => AppTheme.secondary,
      'absent' => const Color(0xFFB91C1C),
      _ => const Color(0xFFCBD5E1),
    };
  }

  Color get _textColor {
    return member.status == 'absent'
        ? const Color(0xFFB91C1C)
        : AppTheme.textStrong;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: formMotionDuration(context, 200),
      constraints: const BoxConstraints(minHeight: 138),
      decoration: BoxDecoration(
        color: member.status == 'normal'
            ? const Color(0xFFEFFAF3)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: _accentColor, width: 5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.032),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _MemberInfo(member: member, textColor: _textColor),
                    ),
                    const SizedBox(width: 10),
                    AnimatedSwitcher(
                      duration: formMotionDuration(context, 150),
                      child: _TrailingStatus(
                        key: ValueKey(
                          '${member.id}-${checking ? 'saving' : member.status}',
                        ),
                        member: member,
                        checking: checking,
                        enabled: enabled,
                        showCheckinButton: _showCheckinButton,
                        onCheckin: onCheckin,
                        onEditRemark: onEditRemark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberInfo extends StatelessWidget {
  const _MemberInfo({required this.member, required this.textColor});

  final SessionMember member;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final studentId = member.studentId.isEmpty ? '未填学号' : member.studentId;
    final groupName = member.groupName.isEmpty ? '未分组' : member.groupName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          member.memberName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 2,
          children: [
            _MetaText(icon: Icons.badge_outlined, text: studentId),
            _MetaText(icon: Icons.groups_2_outlined, text: groupName),
          ],
        ),
        const SizedBox(height: 4),
        if (member.checkinTime == null)
          const _MetaText(icon: Icons.schedule_outlined, text: '暂未签到')
        else
          _MetaText(
            icon: Icons.check_circle_outline,
            text: '签到 ${formatDateTime(member.checkinTime!).substring(11)}',
            color: member.status == 'late'
                ? const Color(0xFFB45309)
                : AppTheme.textMuted,
          ),
        const SizedBox(height: 4),
        Text(
          '备注：${member.remark.trim().isEmpty ? '暂无备注' : member.remark}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w700,
            height: 1.18,
          ),
        ),
      ],
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.textMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: effectiveColor),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 138),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: effectiveColor,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrailingStatus extends StatelessWidget {
  const _TrailingStatus({
    super.key,
    required this.member,
    required this.checking,
    required this.enabled,
    required this.showCheckinButton,
    required this.onCheckin,
    required this.onEditRemark,
  });

  final SessionMember member;
  final bool checking;
  final bool enabled;
  final bool showCheckinButton;
  final VoidCallback? onCheckin;
  final VoidCallback onEditRemark;

  @override
  Widget build(BuildContext context) {
    if (showCheckinButton) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 84,
            height: 48,
            child: PressFeedback(
              enabled: enabled && !checking,
              child: ElevatedButton(
                onPressed: checking || !enabled ? null : onCheckin,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: checking
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: reduceFormMotion(context)
                                ? const Icon(Icons.hourglass_top, size: 16)
                                : const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                          ),
                          const SizedBox(width: 4),
                          const Text('保存中'),
                        ],
                      )
                    : const Text('签到'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _RemarkButton(onPressed: enabled ? onEditRemark : null),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusTag(status: member.status),
        if (member.status == 'late' && member.lateMinutes > 0) ...[
          const SizedBox(height: 6),
          Text(
            '迟到 ${member.lateMinutes} 分钟',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFFB45309),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        const SizedBox(height: 8),
        _RemarkButton(onPressed: enabled ? onEditRemark : null),
      ],
    );
  }
}

class _RemarkButton extends StatelessWidget {
  const _RemarkButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          textStyle: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text('编辑备注'),
      ),
    );
  }
}
