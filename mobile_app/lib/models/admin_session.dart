class AdminSession {
  const AdminSession({
    required this.id,
    required this.title,
    required this.requiredTime,
    required this.endTime,
    required this.status,
    required this.createdAt,
    required this.stats,
  });

  final String id;
  final String title;
  final DateTime requiredTime;
  final DateTime endTime;
  final String status;
  final DateTime createdAt;
  final SessionStats stats;

  factory AdminSession.fromJson(Map<String, dynamic> json, SessionStats stats) {
    return AdminSession(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      requiredTime: DateTime.parse(json['required_time'] as String).toLocal(),
      endTime: DateTime.parse(json['end_time'] as String).toLocal(),
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      stats: stats,
    );
  }
}

class SessionStats {
  const SessionStats({
    required this.total,
    required this.normal,
    required this.late,
    required this.absent,
    required this.pending,
  });

  factory SessionStats.empty() {
    return const SessionStats(
      total: 0,
      normal: 0,
      late: 0,
      absent: 0,
      pending: 0,
    );
  }

  final int total;
  final int normal;
  final int late;
  final int absent;
  final int pending;

  int get checked => normal + late;
}

class CreateSessionInput {
  const CreateSessionInput({
    required this.title,
    required this.requiredTime,
    required this.endTime,
    required this.memberIds,
  });

  final String title;
  final DateTime requiredTime;
  final DateTime endTime;
  final List<String> memberIds;
}
