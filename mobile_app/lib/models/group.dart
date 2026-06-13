class TeamGroup {
  const TeamGroup({
    required this.id,
    required this.name,
    this.description,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? description;
  final DateTime? createdAt;

  factory TeamGroup.fromJson(Map<String, dynamic> json) {
    return TeamGroup(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

class GroupInput {
  const GroupInput({required this.name, this.description});

  final String name;
  final String? description;

  Map<String, dynamic> toJson() {
    return {'name': name, 'description': description};
  }
}
