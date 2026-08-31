/// 习惯打卡记录（一行 = 某习惯某天打卡）
class HabitCheck {
  const HabitCheck({
    this.id,
    required this.habitId,
    required this.date,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final int? id;
  final int habitId;
  final String date; // yyyy-MM-dd
  final int? createdAt;
  final int? updatedAt;
  final int? deletedAt;

  bool get isDeleted => deletedAt != null;

  HabitCheck copyWith({
    int? id,
    int? habitId,
    String? date,
    int? createdAt,
    int? updatedAt,
    int? deletedAt,
  }) {
    return HabitCheck(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'habitId': habitId,
        'date': date,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deletedAt': deletedAt,
      };

  factory HabitCheck.fromMap(Map<String, Object?> map) => HabitCheck(
        id: map['id'] as int?,
        habitId: map['habitId'] as int? ?? 0,
        date: map['date'] as String? ?? '',
        createdAt: map['createdAt'] as int?,
        updatedAt: map['updatedAt'] as int?,
        deletedAt: map['deletedAt'] as int?,
      );

  @override
  bool operator ==(Object other) =>
      other is HabitCheck &&
      other.habitId == habitId &&
      other.date == date &&
      other.updatedAt == updatedAt;
  @override
  int get hashCode => Object.hash(habitId, date, updatedAt);
}

/// 习惯定义
class Habit {
  const Habit({
    this.id,
    required this.name,
    this.color = 0xFF30A46C,
    this.targetDays = 0,
    this.archived = false,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final int? id;
  final String name;
  final int color;

  /// 每周目标天数；0 = 每天
  final int targetDays;
  final bool archived;
  final int sortOrder;
  final int? createdAt;
  final int? updatedAt;
  final int? deletedAt;

  bool get isDeleted => deletedAt != null;

  Habit copyWith({
    int? id,
    String? name,
    int? color,
    int? targetDays,
    bool? archived,
    int? sortOrder,
    int? createdAt,
    int? updatedAt,
    int? deletedAt,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      targetDays: targetDays ?? this.targetDays,
      archived: archived ?? this.archived,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'color': color,
        'targetDays': targetDays,
        'archived': archived ? 1 : 0,
        'sortOrder': sortOrder,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deletedAt': deletedAt,
      };

  factory Habit.fromMap(Map<String, Object?> map) => Habit(
        id: map['id'] as int?,
        name: map['name'] as String? ?? '',
        color: map['color'] as int? ?? 0xFF30A46C,
        targetDays: map['targetDays'] as int? ?? 0,
        archived: (map['archived'] as int? ?? 0) == 1,
        sortOrder: map['sortOrder'] as int? ?? 0,
        createdAt: map['createdAt'] as int?,
        updatedAt: map['updatedAt'] as int?,
        deletedAt: map['deletedAt'] as int?,
      );

  @override
  bool operator ==(Object other) =>
      other is Habit && other.id == id && other.updatedAt == updatedAt;
  @override
  int get hashCode => Object.hash(id, updatedAt);
}

/// 番茄专注会话
class PomodoroSession {
  const PomodoroSession({
    this.id,
    this.taskId,
    this.taskTitle = '',
    required this.startedAt,
    this.durationMinutes = 25,
    this.completed = true,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final int? id;
  final int? taskId; // 可空：不关联任务
  final String taskTitle;
  final int startedAt; // epoch ms
  final int durationMinutes;
  final bool completed; // false = 中途放弃
  final int? createdAt;
  final int? updatedAt;
  final int? deletedAt;

  bool get isDeleted => deletedAt != null;

  PomodoroSession copyWith({
    int? id,
    int? taskId,
    String? taskTitle,
    int? startedAt,
    int? durationMinutes,
    bool? completed,
    int? createdAt,
    int? updatedAt,
    int? deletedAt,
  }) {
    return PomodoroSession(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      taskTitle: taskTitle ?? this.taskTitle,
      startedAt: startedAt ?? this.startedAt,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'taskId': taskId,
        'taskTitle': taskTitle,
        'startedAt': startedAt,
        'durationMinutes': durationMinutes,
        'completed': completed ? 1 : 0,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deletedAt': deletedAt,
      };

  factory PomodoroSession.fromMap(Map<String, Object?> map) => PomodoroSession(
        id: map['id'] as int?,
        taskId: map['taskId'] as int?,
        taskTitle: map['taskTitle'] as String? ?? '',
        startedAt: map['startedAt'] as int? ?? 0,
        durationMinutes: map['durationMinutes'] as int? ?? 25,
        completed: (map['completed'] as int? ?? 1) == 1,
        createdAt: map['createdAt'] as int?,
        updatedAt: map['updatedAt'] as int?,
        deletedAt: map['deletedAt'] as int?,
      );

  @override
  bool operator ==(Object other) =>
      other is PomodoroSession &&
      other.id == id &&
      other.updatedAt == updatedAt;
  @override
  int get hashCode => Object.hash(id, updatedAt);
}
