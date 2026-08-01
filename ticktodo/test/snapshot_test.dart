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
      final snap = await buildSnapshot(appDb, 0, now: () => now);
      expect(snap.tasks.single.isDeleted, true);

      await appDb.db.delete('tasks');
      await applySnapshot(appDb, snap);
      final restored = await appDb.db.query('tasks');
      expect(restored.length, 1);
      expect(Task.fromMap(restored.first).isDeleted, true);
    });

    test('空表不崩，revision 取 now', () async {
      final snap = await buildSnapshot(appDb, 0, now: () => 42);
      expect(snap.tasks, isEmpty);
      expect(snap.revision, 42);
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

    test('taskTags union 去重', () {
      final a = SyncSnapshot(revision: 1, tasks: [], subtasks: [], lists: [], tags: [], taskTags: [TaskTagLink(taskId: 1, tagId: 1)]);
      final b = SyncSnapshot(revision: 2, tasks: [], subtasks: [], lists: [], tags: [], taskTags: [TaskTagLink(taskId: 1, tagId: 2)]);
      final m = mergeSnapshots(a, b);
      expect(m.taskTags.length, 2);
    });
  });
}
