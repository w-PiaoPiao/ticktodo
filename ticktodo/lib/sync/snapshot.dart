import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/list_model.dart';
import 'package:ticktodo/data/models/subtask.dart';
import 'package:ticktodo/data/models/tag.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/data/models/task_tag_link.dart';

class SyncSnapshot {
  const SyncSnapshot({
    required this.revision,
    required this.tasks,
    required this.subtasks,
    required this.lists,
    required this.tags,
    required this.taskTags,
  });

  final int revision;
  final List<Task> tasks;
  final List<Subtask> subtasks;
  final List<ListModel> lists;
  final List<Tag> tags;
  final List<TaskTagLink> taskTags;

  Map<String, dynamic> toJson() => {
        'revision': revision,
        'tasks': tasks.map((t) => t.toMap()).toList(),
        'subtasks': subtasks.map((s) => s.toMap()).toList(),
        'lists': lists.map((l) => l.toMap()).toList(),
        'tags': tags.map((t) => t.toMap()).toList(),
        'taskTags': taskTags.map((l) => l.toMap()).toList(),
      };

  factory SyncSnapshot.fromJson(Map<String, dynamic> json) => SyncSnapshot(
        revision: json['revision'] as int? ?? 0,
        tasks: ((json['tasks'] as List?) ?? [])
            .map((e) => Task.fromMap((e as Map).cast<String, Object?>()))
            .toList(),
        subtasks: ((json['subtasks'] as List?) ?? [])
            .map((e) => Subtask.fromMap((e as Map).cast<String, Object?>()))
            .toList(),
        lists: ((json['lists'] as List?) ?? [])
            .map((e) => ListModel.fromMap((e as Map).cast<String, Object?>()))
            .toList(),
        tags: ((json['tags'] as List?) ?? [])
            .map((e) => Tag.fromMap((e as Map).cast<String, Object?>()))
            .toList(),
        taskTags: ((json['taskTags'] as List?) ?? [])
            .map((e) => TaskTagLink.fromMap((e as Map).cast<String, Object?>()))
            .toList(),
      );

  String encode() => jsonEncode(toJson());
}

/// 从数据库构建完整快照（含软删除记录）。
Future<SyncSnapshot> buildSnapshot(
  AppDatabase appDb,
  int revision, {
  int Function()? now,
}) async {
  final tasks = await appDb.db
      .query('tasks')
      .then((rows) => rows.map(Task.fromMap).toList());
  final subtasks = await appDb.db
      .query('subtasks')
      .then((rows) => rows.map(Subtask.fromMap).toList());
  final lists = await appDb.db
      .query('lists')
      .then((rows) => rows.map(ListModel.fromMap).toList());
  final tags = await appDb.db
      .query('tags')
      .then((rows) => rows.map(Tag.fromMap).toList());
  final taskTags = await appDb.db
      .query('task_tags')
      .then((rows) => rows.map(TaskTagLink.fromMap).toList());

  final maxUpdated = <int?>[
    tasks.map((t) => t.updatedAt).fold<int?>(null, (a, b) => a == null || (b != null && b > a) ? b : a),
    subtasks.map((s) => s.updatedAt).fold<int?>(null, (a, b) => a == null || (b != null && b > a) ? b : a),
    lists.map((l) => l.updatedAt).fold<int?>(null, (a, b) => a == null || (b != null && b > a) ? b : a),
    tags.map((t) => t.updatedAt).fold<int?>(null, (a, b) => a == null || (b != null && b > a) ? b : a),
  ].fold<int?>(null, (a, b) => a == null || (b != null && b > a) ? b : a);

  return SyncSnapshot(
    revision: revision > (maxUpdated ?? 0)
        ? revision
        : (now?.call() ?? DateTime.now().millisecondsSinceEpoch),
    tasks: tasks,
    subtasks: subtasks,
    lists: lists,
    tags: tags,
    taskTags: taskTags,
  );
}

/// 将快照整体应用到数据库（事务内替换式写入）。
Future<void> applySnapshot(AppDatabase appDb, SyncSnapshot snapshot) async {
  final db = appDb.db;
  await db.transaction((txn) async {
    final batch = txn.batch();
    for (final t in snapshot.tasks) {
      if (t.id == null) {
        batch.insert('tasks', t.toMap()..remove('id'));
      } else {
        batch.insert('tasks', t.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    for (final s in snapshot.subtasks) {
      if (s.id == null) {
        batch.insert('subtasks', s.toMap()..remove('id'));
      } else {
        batch.insert('subtasks', s.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    for (final l in snapshot.lists) {
      if (l.id == null) {
        batch.insert('lists', l.toMap()..remove('id'));
      } else {
        batch.insert('lists', l.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    for (final t in snapshot.tags) {
      if (t.id == null) {
        batch.insert('tags', t.toMap()..remove('id'));
      } else {
        batch.insert('tags', t.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    await batch.commit(noResult: true);
    await txn.delete('task_tags');
    final linkBatch = txn.batch();
    for (final l in snapshot.taskTags) {
      linkBatch.insert('task_tags', l.toMap());
    }
    await linkBatch.commit(noResult: true);
  });
}
