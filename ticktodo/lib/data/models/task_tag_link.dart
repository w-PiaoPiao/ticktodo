class TaskTagLink {
  const TaskTagLink({required this.taskId, required this.tagId});

  final int taskId;
  final int tagId;

  Map<String, Object?> toMap() => {'taskId': taskId, 'tagId': tagId};

  factory TaskTagLink.fromMap(Map<String, Object?> map) => TaskTagLink(
        taskId: map['taskId'] as int,
        tagId: map['tagId'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is TaskTagLink && other.taskId == taskId && other.tagId == tagId;
  @override
  int get hashCode => Object.hash(taskId, tagId);
}
