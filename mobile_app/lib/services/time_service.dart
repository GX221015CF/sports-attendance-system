class CheckinPreview {
  const CheckinPreview({
    required this.canCheckin,
    required this.status,
    required this.lateMinutes,
    required this.message,
  });

  final bool canCheckin;
  final String status;
  final int lateMinutes;
  final String message;
}

class TimeService {
  CheckinPreview previewCheckin({
    required DateTime now,
    required DateTime requiredTime,
    required DateTime endTime,
  }) {
    if (now.isAfter(endTime)) {
      return const CheckinPreview(
        canCheckin: false,
        status: 'closed',
        lateMinutes: 0,
        message: '签到已结束',
      );
    }

    if (!now.isAfter(requiredTime)) {
      return const CheckinPreview(
        canCheckin: true,
        status: 'normal',
        lateMinutes: 0,
        message: '正常签到',
      );
    }

    final diffMinutes = now.difference(requiredTime).inMinutes;
    final lateMinutes = diffMinutes < 1 ? 1 : diffMinutes;

    return CheckinPreview(
      canCheckin: true,
      status: 'late',
      lateMinutes: lateMinutes,
      message: '迟到 $lateMinutes 分钟',
    );
  }
}
