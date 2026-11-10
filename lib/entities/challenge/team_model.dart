class Team {
  const Team({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
  });

  final int id;
  final String name;
  final String color;
  final String icon;

  factory Team.fromMap(Map<String, dynamic> map) => Team(
        id: map['id'] as int,
        name: map['name'] as String,
        color: map['color'] as String? ?? '#0B5FE8',
        icon: map['icon'] as String? ?? 'groups',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color': color,
        'icon': icon,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Team &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
