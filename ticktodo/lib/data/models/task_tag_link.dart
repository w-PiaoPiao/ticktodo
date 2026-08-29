class TaskTagLink {
  const TaskTagLink({
    required this.taskId,
    required this.tagId,
    this.updatedAt,
    this.deletedAt,
  });

  final int taskId;
  final int tagId;

  /// 关联对的逻辑时间戳：同步按 (taskId, tagId) 逐条 LWW 合并。
  /// 旧库迁移后为 NULL，任何新写入都会胜出。
  final int? updatedAt;

  /// 非空表示"取消标签"墓碑：取消操作要作为事件同步到其他设备，
  /// 因此软删行参与快照与合并（与 tasks/habits 同一套模式）。
  final int? deletedAt;

  bool get isDeleted => deletedAt != null;

  Map<String, Object?> toMap() => {
        'taskId': taskId,
        'tagId': tagId,
        if (updatedAt != null) 'updatedAt': updatedAt,
        if (deletedAt != null) 'deletedAt': deletedAt,
      };

  factory TaskTagLink.fromMap(Map<String, Object?> map) => TaskTagLink(
        taskId: map['taskId'] as int,
        tagId: map['tagId'] as int,
        updatedAt: map['updatedAt'] as int?,
        deletedAt: map['deletedAt'] as int?,
      );

  @override
  bool operator ==(Object other) =>
      other is TaskTagLink && other.taskId == taskId && other.tagId == tagId;
  @override
  int get hashCode => Object.hash(taskId, tagId);
}
