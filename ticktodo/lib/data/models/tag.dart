class Tag {
  const Tag({
    this.id,
    required this.name,
    this.color = 0xFF4C9AFF,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final int? id;
  final String name;
  final int color;
  final int? createdAt;
  final int? updatedAt;
  final int? deletedAt;

  bool get isDeleted => deletedAt != null;

  Tag copyWith({
    int? id,
    String? name,
    int? color,
    int? createdAt,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'color': color,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deletedAt': deletedAt,
      };

  factory Tag.fromMap(Map<String, Object?> map) => Tag(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        color: map['color'] as int? ?? 0xFF4C9AFF,
        createdAt: map['createdAt'] as int?,
        updatedAt: map['updatedAt'] as int?,
        deletedAt: map['deletedAt'] as int?,
      );

  @override
  bool operator ==(Object other) =>
      other is Tag && other.id == id && other.updatedAt == updatedAt;
  @override
  int get hashCode => Object.hash(id, updatedAt);
}
