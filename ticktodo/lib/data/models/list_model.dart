class ListModel {
  const ListModel({
    this.id,
    required this.name,
    this.color = 0xFF2F9D45,
    this.icon = 0,
    this.sortOrder = 0,
    this.isDefault = false,
    this.isPinned = false,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final int? id;
  final String name;
  final int color;
  final int icon;
  final int sortOrder;
  final bool isDefault;
  final bool isPinned;
  final int? createdAt;
  final int? updatedAt;
  final int? deletedAt;

  bool get isDeleted => deletedAt != null;

  ListModel copyWith({
    int? id,
    String? name,
    int? color,
    int? icon,
    int? sortOrder,
    bool? isDefault,
    bool? isPinned,
    int? createdAt,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return ListModel(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'color': color,
        'icon': icon,
        'sortOrder': sortOrder,
        'isDefault': isDefault ? 1 : 0,
        'isPinned': isPinned ? 1 : 0,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deletedAt': deletedAt,
      };

  factory ListModel.fromMap(Map<String, Object?> map) => ListModel(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        color: map['color'] as int? ?? 0xFF2F9D45,
        icon: map['icon'] as int? ?? 0,
        sortOrder: map['sortOrder'] as int? ?? 0,
        isDefault: (map['isDefault'] as int? ?? 0) == 1,
        isPinned: (map['isPinned'] as int? ?? 0) == 1,
        createdAt: map['createdAt'] as int?,
        updatedAt: map['updatedAt'] as int?,
        deletedAt: map['deletedAt'] as int?,
      );

  @override
  bool operator ==(Object other) =>
      other is ListModel && other.id == id && other.updatedAt == updatedAt;
  @override
  int get hashCode => Object.hash(id, updatedAt);
}
