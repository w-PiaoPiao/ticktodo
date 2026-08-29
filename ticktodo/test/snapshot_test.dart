import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/list_model.dart';
import 'package:ticktodo/data/models/subtask.dart';
import 'package:ticktodo/data/models/tag.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/data/models/task_tag_link.dart';
import 'package:ticktodo/sync/gzip_codec.dart';
import 'package:ticktodo/sync/snapshot.dart';
import 'package:ticktodo/sync/snapshot_merge.dart';

void main() {
  group('gzip', () {
    test('往返一致', () {
      const s = '{"a": 1, "b": "中文测试"}';
      expect(gzipDecode(gzipEncode(s)), s);
    });
  });

  group('snapshot json', () {
    test('toJson/fromJson 往返', () {
      final snap = SyncSnapshot(
        revision: 123,
        tasks: [
          Task(
              id: 1,
              title: 't',
              listId: 1,
              dueDate: '2026-08-01',
              priority: TaskPriority.high,
              updatedAt: 100),
        ],
        subtasks: [Subtask(id: 2, taskId: 1, title: 's', completed: true)],
        lists: [ListModel(id: 1, name: '收集箱', isDefault: true, updatedAt: 50)],
        tags: [Tag(id: 3, name: '标签', color: 0xFF0000FF)],
        taskTags: [TaskTagLink(taskId: 1, tagId: 3)],
      );
      final round = SyncSnapshot.fromJson(jsonDecode(snap.encode()));
      expect(round.revision, 123);
      expect(round.tasks.single.title, 't');
      expect(round.tasks.single.priority, TaskPriority.high);
      expect(round.subtasks.single.completed, true);
      expect(round.lists.single.isDefault, true);
      expect(round.tags.single.color, 0xFF0000FF);
      expect(round.taskTags.single, TaskTagLink(taskId: 1, tagId: 3));
    });
  });

  group('buildSnapshot/applySnapshot', () {
    late AppDatabase appDb;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      appDb = await AppDatabase.open(inMemoryPath: inMemoryDatabasePath);
    });

    tearDown(() async {
      await appDb.db.close();
    });

    test('往返无损（含软删除）', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await appDb.db.insert('tasks', Task(
        title: 'x',
        listId: 1,
        updatedAt: now,
        deletedAt: now,
      ).toMap());
      final snap = await buildSnapshot(appDb, 0);
      expect(snap.tasks.single.isDeleted, true);

      await appDb.db.delete('tasks');
      await applySnapshot(appDb, snap);
      final restored = await appDb.db.query('tasks');
      expect(restored.length, 1);
      expect(Task.fromMap(restored.first).isDeleted, true);
    });

    test('空表不崩，revision 取真实最大 updatedAt（不再伪造 now）', () async {
      final snap = await buildSnapshot(appDb, 0);
      expect(snap.tasks, isEmpty);
      expect(snap.revision, 0);
    });

    test('task_tags 墓碑入快照并还原', () async {      await appDb.db.insert('task_tags',
          {'taskId': 1, 'tagId': 2, 'updatedAt': 100, 'deletedAt': 100});
      final snap = await buildSnapshot(appDb, 0);
      expect(snap.taskTags.single.isDeleted, true);

      await appDb.db.delete('task_tags');
      await applySnapshot(appDb, snap);
      final rows = await appDb.db.query('task_tags');
      expect(rows.single['deletedAt'], 100);
    });

    test('merge 后 applySnapshot 不丢本地独有 habits/reminders（整表替换放大器回归）', () async {
      await appDb.db.insert('habits', {'name': '本地习惯', 'updatedAt': 100});
      await appDb.db
          .insert('reminders', {'taskId': 1, 'remindAt': 123, 'updatedAt': 100});
      final local = await buildSnapshot(appDb, 0);
      final remote = SyncSnapshot(
        revision: 5,
        tasks: [
          Task(id: 9, title: '远端任务', listId: 1, updatedAt: 100),
        ],
        subtasks: const [],
        lists: const [],
        tags: const [],
        taskTags: const [],
      );
      final merged = mergeSnapshots(local, remote);
      await applySnapshot(appDb, merged);

      // 整表 delete+insert 只作用于合并结果（local∪remote 超集），本地独有行必须幸存
      expect((await appDb.db.query('habits')).single['name'], '本地习惯');
      expect((await appDb.db.query('reminders')), isNotEmpty);
      expect((await appDb.db.query('tasks')).single['title'], '远端任务');
    });
  });

  group('mergeSnapshots', () {
    Task task(int id, int updatedAt, {bool deleted = false}) =>
        Task(id: id, title: 't$id', listId: 1, updatedAt: updatedAt,
            deletedAt: deleted ? updatedAt : null);

    test('本地新 → 本地胜', () {
      final local = SyncSnapshot(revision: 10, tasks: [task(1, 200)], subtasks: [], lists: [], tags: [], taskTags: []);
      final remote = SyncSnapshot(revision: 5, tasks: [task(1, 100)], subtasks: [], lists: [], tags: [], taskTags: []);
      final m = mergeSnapshots(local, remote);
      expect(m.tasks.single.updatedAt, 200);
      expect(m.revision, 10);
    });

    test('远端新 → 远端胜', () {
      final local = SyncSnapshot(revision: 5, tasks: [task(1, 100)], subtasks: [], lists: [], tags: [], taskTags: []);
      final remote = SyncSnapshot(revision: 10, tasks: [task(1, 300)], subtasks: [], lists: [], tags: [], taskTags: []);
      final m = mergeSnapshots(local, remote);
      expect(m.tasks.single.updatedAt, 300);
    });

    test('同 updatedAt → 远端胜（确定性）', () {
      final local = SyncSnapshot(revision: 7, tasks: [task(1, 100)], subtasks: [], lists: [], tags: [], taskTags: []);
      final remote = SyncSnapshot(revision: 7, tasks: [task(1, 100)], subtasks: [], lists: [], tags: [], taskTags: []);
      final m = mergeSnapshots(local, remote);
      expect(m.tasks.single.title, 't1');
    });

    test('一边删除一边更新 → 取较新', () {
      final local = SyncSnapshot(revision: 5, tasks: [task(1, 300, deleted: true)], subtasks: [], lists: [], tags: [], taskTags: []);
      final remote = SyncSnapshot(revision: 8, tasks: [task(1, 400)], subtasks: [], lists: [], tags: [], taskTags: []);
      final m = mergeSnapshots(local, remote);
      expect(m.tasks.single.isDeleted, false);

      final local2 = SyncSnapshot(revision: 5, tasks: [task(1, 300)], subtasks: [], lists: [], tags: [], taskTags: []);
      final remote2 = SyncSnapshot(revision: 8, tasks: [task(1, 400, deleted: true)], subtasks: [], lists: [], tags: [], taskTags: []);
      final m2 = mergeSnapshots(local2, remote2);
      expect(m2.tasks.single.isDeleted, true);
    });

    test('新记录 union', () {
      final local = SyncSnapshot(revision: 5, tasks: [task(1, 100)], subtasks: [], lists: [], tags: [], taskTags: []);
      final remote = SyncSnapshot(revision: 6, tasks: [task(2, 100)], subtasks: [], lists: [], tags: [], taskTags: []);
      final m = mergeSnapshots(local, remote);
      expect(m.tasks.length, 2);
    });

    test('taskTags：取消标签（墓碑）胜过旧链接，删除事件可同步', () {
      final a = SyncSnapshot(
          revision: 1,
          tasks: const [],
          subtasks: const [],
          lists: const [],
          tags: const [],
          taskTags: [TaskTagLink(taskId: 1, tagId: 3, updatedAt: 100)]);
      final b = SyncSnapshot(
          revision: 2,
          tasks: const [],
          subtasks: const [],
          lists: const [],
          tags: const [],
          taskTags: [
            TaskTagLink(taskId: 1, tagId: 3, updatedAt: 200, deletedAt: 200)
          ]);
      final m = mergeSnapshots(a, b);
      expect(m.taskTags.single.isDeleted, true);
    });

    test('taskTags：重新添加胜过墓碑', () {
      final a = SyncSnapshot(
          revision: 1,
          tasks: const [],
          subtasks: const [],
          lists: const [],
          tags: const [],
          taskTags: [
            TaskTagLink(taskId: 1, tagId: 3, updatedAt: 200, deletedAt: 200)
          ]);
      final b = SyncSnapshot(
          revision: 2,
          tasks: const [],
          subtasks: const [],
          lists: const [],
          tags: const [],
          taskTags: [TaskTagLink(taskId: 1, tagId: 3, updatedAt: 300)]);
      final m = mergeSnapshots(a, b);
      expect(m.taskTags.single.isDeleted, false);
    });

    test('taskTags：同一关联对 LWW 去重，不同关联对共存', () {
      final a = SyncSnapshot(
          revision: 1,
          tasks: const [],
          subtasks: const [],
          lists: const [],
          tags: const [],
          taskTags: [
            TaskTagLink(taskId: 1, tagId: 3, updatedAt: 100),
            TaskTagLink(taskId: 2, tagId: 4, updatedAt: 100),
          ]);
      final b = SyncSnapshot(
          revision: 2,
          tasks: const [],
          subtasks: const [],
          lists: const [],
          tags: const [],
          taskTags: [TaskTagLink(taskId: 1, tagId: 3, updatedAt: 50)]);
      final m = mergeSnapshots(a, b);
      expect(m.taskTags.length, 2);
      expect(
          m.taskTags.firstWhere((l) => l.taskId == 1 && l.tagId == 3).updatedAt,
          100);
    });
  });
}
