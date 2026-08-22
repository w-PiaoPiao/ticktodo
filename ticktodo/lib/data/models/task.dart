enum TaskPriority {
  none(0, '无', 0xFF9E9E9E),
  low(1, '低', 0xFF4C9AFF),
  medium(2, '中', 0xFF2F9D45),
  high(3, '高', 0xFFE04C4C);

  const TaskPriority(this.value, this.label, this.colorValue);
  final int value;
  final String label;
  final int colorValue;

  static TaskPriority fromValue(int? v) =>
      TaskPriority.values.firstWhere((p) => p.value == v, orElse: () => TaskPriority.none);
}

class Task {
  const Task({
    this.id,
    required this.title,
    this.note = '',
    this.completed = false,
    this.priority = TaskPriority.none,
    this.dueDate,
    this.dueTime,
    this.remindAt,
    required this.listId,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.repeatRule,
  });

  final int? id;
  final String title;
  final String note;
  final bool completed;
  final TaskPriority priority;
  final String? dueDate; // yyyy-MM-dd
  final String? dueTime; // HH:mm
  final int? remindAt; // epoch ms
  final int listId;
  final int sortOrder;
  final int? createdAt;
  final int? updatedAt;
  final int? deletedAt;

  /// 重复规则（简化 RRULE 编码），null = 不重复。
  final String? repeatRule;

  bool get isDeleted => deletedAt != null;

  Task copyWith({
    int? id,
    String? title,
    String? note,
    bool? completed,
    TaskPriority? priority,
    String? dueDate,
    String? dueTime,
    int? remindAt,
    int? listId,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
    int? deletedAt,
    String? repeatRule,
    bool clearDueDate = false,
    bool clearDueTime = false,
    bool clearRemindAt = false,
    bool clearDeletedAt = false,
    bool clearRepeatRule = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      dueTime: clearDueTime ? null : (dueTime ?? this.dueTime),
      remindAt: clearRemindAt ? null : (remindAt ?? this.remindAt),
      listId: listId ?? this.listId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      repeatRule: clearRepeatRule ? null : (repeatRule ?? this.repeatRule),
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'note': note,
        'completed': completed ? 1 : 0,
        'priority': priority.value,
        'dueDate': dueDate,
        'dueTime': dueTime,
        'remindAt': remindAt,
        'listId': listId,
        'sortOrder': sortOrder,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deletedAt': deletedAt,
        'repeatRule': repeatRule,
      };

  factory Task.fromMap(Map<String, Object?> map) => Task(
        id: map['id'] as int?,
        title: map['title'] as String? ?? '',
        note: map['note'] as String? ?? '',
        completed: (map['completed'] as int? ?? 0) == 1,
        priority: TaskPriority.fromValue(map['priority'] as int?),
        dueDate: map['dueDate'] as String?,
        dueTime: map['dueTime'] as String?,
        remindAt: map['remindAt'] as int?,
        listId: map['listId'] as int? ?? 0,
        sortOrder: map['sortOrder'] as int? ?? 0,
        createdAt: map['createdAt'] as int?,
        updatedAt: map['updatedAt'] as int?,
        deletedAt: map['deletedAt'] as int?,
        repeatRule: map['repeatRule'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is Task && other.id == id && other.updatedAt == updatedAt;
  @override
  int get hashCode => Object.hash(id, updatedAt);
}
