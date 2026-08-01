class Subtask {
  const Subtask({
    this.id,
    required this.taskId,
    required this.title,
    this.completed = false,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final int? id;
  final int taskId;
  final String title;
  final bool completed;
  final int sortOrder;
  final int? createdAt;
  final int? updatedAt;
  final int? deletedAt;

  bool get isDeleted => deletedAt != null;

  Subtask copyWith({
    int? id,
    int? taskId,
    String? title,
    bool? completed,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Subtask(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'taskId': taskId,
        'title': title,
        'completed': completed ? 1 : 0,
        'sortOrder': sortOrder,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deletedAt': deletedAt,
      };

  factory Subtask.fromMap(Map<String, Object?> map) => Subtask(
        id: map['id'] as int?,
        taskId: map['taskId'] as int? ?? 0,
        title: map['title'] as String? ?? '',
        completed: (map['completed'] as int? ?? 0) == 1,
        sortOrder: map['sortOrder'] as int? ?? 0,
        createdAt: map['createdAt'] as int?,
        updatedAt: map['updatedAt'] as int?,
        deletedAt: map['deletedAt'] as int?,
      );

  @override
  bool operator ==(Object other) =>
      other is Subtask && other.id == id && other.updatedAt == updatedAt;
  @override
  int get hashCode => Object.hash(id, updatedAt);
}
