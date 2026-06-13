class TeamGroup {
  const TeamGroup({required this.id, required this.name, this.description});

  final String id;
  final String name;
  final String? description;

  factory TeamGroup.fromJson(Map<String, dynamic> json) {
    return TeamGroup(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
    );
  }
}
