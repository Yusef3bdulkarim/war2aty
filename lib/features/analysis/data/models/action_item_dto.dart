final class ActionItemDto {
  const ActionItemDto({
    required this.description,
    required this.basis,
    required this.priority,
  });

  factory ActionItemDto.fromJson(Map<String, dynamic> json) {
    return ActionItemDto(
      description: json['description'] as String,
      basis: json['basis'] as String,
      priority: json['priority'] as String,
    );
  }

  final String description;

  /// Raw wire enum — `explicit` | `inferred`.
  final String basis;

  /// Raw wire enum — `high` | `normal`.
  final String priority;

  Map<String, dynamic> toJson() => {
    'description': description,
    'basis': basis,
    'priority': priority,
  };
}
