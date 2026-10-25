class SessionMember {
  const SessionMember({
    required this.id,
    required this.sessionId,
    required this.memberId,
    required this.status,
    required this.checkinTime,
    required this.lateMinutes,
    required this.memberName,
    required this.studentId,
    required this.gender,
    required this.phone,
    required this.groupName,
    required this.remark,
  });

  final String id;
  final String sessionId;
  final String memberId;
  final String status;
  final DateTime? checkinTime;
  final int lateMinutes;
  final String memberName;
  final String studentId;
  final String gender;
  final String phone;
  final String groupName;
  final String remark;

  /// Used only after persistence confirms the check-in was recorded.
  SessionMember recordedCheckin({
    required String status,
    required DateTime time,
    required int lateMinutes,
  }) => SessionMember(
    id: id,
    sessionId: sessionId,
    memberId: memberId,
    status: status,
    checkinTime: time,
    lateMinutes: lateMinutes,
    memberName: memberName,
    studentId: studentId,
    gender: gender,
    phone: phone,
    groupName: groupName,
    remark: remark,
  );

  factory SessionMember.fromJson(Map<String, dynamic> json) {
    final memberJson = json['members'] as Map<String, dynamic>? ?? {};
    final groupJson = memberJson['groups'] as Map<String, dynamic>? ?? {};
    final checkinTimeText = json['checkin_time'] as String?;

    return SessionMember(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      memberId: json['member_id'] as String,
      status: json['status'] as String? ?? 'pending',
      checkinTime: checkinTimeText == null
          ? null
          : DateTime.parse(checkinTimeText).toLocal(),
      lateMinutes: json['late_minutes'] as int? ?? 0,
      memberName: memberJson['name'] as String? ?? '-',
      studentId: memberJson['student_id'] as String? ?? '-',
      gender: memberJson['gender'] as String? ?? '-',
      phone: memberJson['phone'] as String? ?? '-',
      groupName: groupJson['name'] as String? ?? '未分组',
      remark: json['remark'] as String? ?? '',
    );
  }
}
