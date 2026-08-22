/// 任务的额外提醒时间点（主提醒仍存 tasks.remindAt）。
class Reminder {
  const Reminder({
    this.id,
    required this.taskId,
    required this.remindAt,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
  });

  final int? id;
  final int taskId;
  final int remindAt; // epoch ms
  final int? createdAt;
  final int? updatedAt;
  final int? deletedAt;

  bool get isDeleted => deletedAt != null;

  Reminder copyWith({
    int? id,
    int? taskId,
    int? remindAt,
    int? createdAt,
    int? updatedAt,
    int? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Reminder(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      remindAt: remindAt ?? this.remindAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'taskId': taskId,
        'remindAt': remindAt,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deletedAt': deletedAt,
      };

  factory Reminder.fromMap(Map<String, Object?> map) => Reminder(
        id: map['id'] as int?,
        taskId: map['taskId'] as int? ?? 0,
        remindAt: map['remindAt'] as int? ?? 0,
        createdAt: map['createdAt'] as int?,
        updatedAt: map['updatedAt'] as int?,
        deletedAt: map['deletedAt'] as int?,
      );

  @override
  bool operator ==(Object other) =>
      other is Reminder && other.id == id && other.updatedAt == updatedAt;
  @override
  int get hashCode => Object.hash(id, updatedAt);
}
