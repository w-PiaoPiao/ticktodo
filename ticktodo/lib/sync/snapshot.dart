import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/filter.dart';
import 'package:ticktodo/data/models/habit.dart';
import 'package:ticktodo/data/models/list_model.dart';
import 'package:ticktodo/data/models/reminder.dart';
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
    this.reminders = const [],
    this.filters = const [],
    this.habits = const [],
    this.habitChecks = const [],
    this.pomodoros = const [],
  });

  final int revision;
  final List<Task> tasks;
  final List<Subtask> subtasks;
  final List<ListModel> lists;
  final List<Tag> tags;
  final List<TaskTagLink> taskTags;
  final List<Reminder> reminders;
  final List<Filter> filters;
  final List<Habit> habits;
  final List<HabitCheck> habitChecks;
  final List<PomodoroSession> pomodoros;

  Map<String, dynamic> toJson() => {
        'revision': revision,
        'tasks': tasks.map((t) => t.toMap()).toList(),
        'subtasks': subtasks.map((s) => s.toMap()).toList(),
        'lists': lists.map((l) => l.toMap()).toList(),
        'tags': tags.map((t) => t.toMap()).toList(),
        'taskTags': taskTags.map((l) => l.toMap()).toList(),
        'reminders': reminders.map((r) => r.toMap()).toList(),
        'filters': filters.map((f) => f.toMap()).toList(),
        'habits': habits.map((h) => h.toMap()).toList(),
        'habitChecks': habitChecks.map((h) => h.toMap()).toList(),
        'pomodoros': pomodoros.map((p) => p.toMap()).toList(),
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
        reminders: ((json['reminders'] as List?) ?? [])
            .map((e) => Reminder.fromMap((e as Map).cast<String, Object?>()))
            .toList(),
        filters: ((json['filters'] as List?) ?? [])
            .map((e) => Filter.fromMap((e as Map).cast<String, Object?>()))
            .toList(),
        habits: ((json['habits'] as List?) ?? [])
            .map((e) => Habit.fromMap((e as Map).cast<String, Object?>()))
            .toList(),
        habitChecks: ((json['habitChecks'] as List?) ?? [])
            .map((e) => HabitCheck.fromMap((e as Map).cast<String, Object?>()))
            .toList(),
        pomodoros: ((json['pomodoros'] as List?) ?? [])
            .map((e) => PomodoroSession.fromMap((e as Map).cast<String, Object?>()))
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
  final reminders = await appDb.db
      .query('reminders', where: 'deletedAt IS NULL')
      .then((rows) => rows.map(Reminder.fromMap).toList());
  final filters = await appDb.db
      .query('filters', where: 'deletedAt IS NULL')
      .then((rows) => rows.map(Filter.fromMap).toList());
  // 习惯/打卡/番茄与 tasks 一致：全量入快照（含软删行）。
  // 软删行充当墓碑：取消打卡、删除习惯等"负向操作"才能同步到其他设备，
  // 否则远端旧数据会在合并时把本地删除操作覆盖回去（复活 bug）。
  final habits = await appDb.db
      .query('habits')
      .then((rows) => rows.map(Habit.fromMap).toList());
  final habitChecks = await appDb.db
      .query('habit_checks')
      .then((rows) => rows.map(HabitCheck.fromMap).toList());
  final pomodoros = await appDb.db
      .query('pomodoros')
      .then((rows) => rows.map(PomodoroSession.fromMap).toList());

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
    reminders: reminders,
    filters: filters,
    habits: habits,
    habitChecks: habitChecks,
    pomodoros: pomodoros,
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
    // 额外提醒：先软清后写，保证与快照一致（含"已全部删除"场景）
    await txn.delete('reminders');
    for (final r in snapshot.reminders) {
      if (r.id == null) {
        batch.insert('reminders', r.toMap()..remove('id'));
      } else {
        batch.insert('reminders', r.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    await txn.delete('filters');
    for (final f in snapshot.filters) {
      if (f.id == null) {
        batch.insert('filters', f.toMap()..remove('id'));
      } else {
        batch.insert('filters', f.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    // 习惯与番茄：打卡记录含 UNIQUE(habitId,date)，replace 即可
    await txn.delete('habits');
    for (final h in snapshot.habits) {
      batch.insert('habits', h.id == null
          ? (h.toMap()..remove('id'))
          : h.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await txn.delete('habit_checks');
    for (final h in snapshot.habitChecks) {
      batch.insert('habit_checks', h.id == null
          ? (h.toMap()..remove('id'))
          : h.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await txn.delete('pomodoros');
    for (final p in snapshot.pomodoros) {
      batch.insert('pomodoros', p.id == null
          ? (p.toMap()..remove('id'))
          : p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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
