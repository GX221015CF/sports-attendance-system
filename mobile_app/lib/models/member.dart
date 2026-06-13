class TeamMember {
  const TeamMember({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    this.studentId,
    this.gender,
    this.phone,
    this.groupId,
    this.groupName,
  });

  final String id;
  final String name;
  final String? studentId;
  final String? gender;
  final String? phone;
  final String? groupId;
  final String? groupName;
  final bool isActive;
  final DateTime createdAt;

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    final group = json['groups'] as Map<String, dynamic>?;

    return TeamMember(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      studentId: json['student_id'] as String?,
      gender: json['gender'] as String?,
      phone: json['phone'] as String?,
      groupId: json['group_id'] as String?,
      groupName: group?['name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

class MemberInput {
  const MemberInput({
    required this.name,
    required this.isActive,
    this.studentId,
    this.gender,
    this.phone,
    this.groupId,
  });

  final String name;
  final String? studentId;
  final String? gender;
  final String? phone;
  final String? groupId;
  final bool isActive;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'student_id': studentId,
      'gender': gender,
      'phone': phone,
      'group_id': groupId,
      'is_active': isActive,
    };
  }
}
