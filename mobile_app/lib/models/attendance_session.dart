class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.title,
    required this.requiredTime,
    required this.endTime,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String title;
  final DateTime requiredTime;
  final DateTime endTime;
  final String status;
  final DateTime createdAt;

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    return AttendanceSession(
      id: json['id'] as String,
      title: json['title'] as String,
      requiredTime: DateTime.parse(json['required_time'] as String).toLocal(),
      endTime: DateTime.parse(json['end_time'] as String).toLocal(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
