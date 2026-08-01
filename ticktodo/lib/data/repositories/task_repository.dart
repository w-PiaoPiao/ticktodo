import 'package:sqflite/sqflite.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/subtask.dart';
import 'package:ticktodo/data/models/task.dart';

class TaskRepository {
  TaskRepository(this._appDb);

  final AppDatabase _appDb;
  Database get db => _appDb.db;

  int _lastMutationAt = 0;

  /// 最近一次本地写操作时间（毫秒），用于同步 revision 计算。
  int get lastMutationAt => _lastMutationAt;

  int _now() {
    final n = DateTime.now().millisecondsSinceEpoch;
    if (n > _lastMutationAt) _lastMutationAt = n;
    return n;
  }

  Future<int?> upsertTask(Task task) async {
    final now = _now();
    final t = task.copyWith(updatedAt: now, createdAt: task.createdAt ?? now);
    if (t.id == null) {
      final id = await db.insert('tasks', t.toMap()..remove('id'));
      return id;
    }
    await db.update('tasks', t.toMap(),
        where: 'id = ?', whereArgs: [t.id]);
    return t.id;
  }

  Future<void> bulkUpsertTasks(List<Task> tasks) async {
    final now = _now();
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final task in tasks) {
        final t =
            task.copyWith(updatedAt: now, createdAt: task.createdAt ?? now);
        if (t.id == null) {
          batch.insert('tasks', t.toMap()..remove('id'));
        } else {
          batch.insert('tasks', t.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> softDeleteTask(int id) async {
    final now = _now();
    await db.update('tasks', {'deletedAt': now, 'updatedAt': now},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> restoreTask(int id) async {
    final now = _now();
    await db.update(
        'tasks', {'deletedAt': null, 'updatedAt': now},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> toggleComplete(int id, bool completed) async {
    final now = _now();
    await db.update('tasks', {
      'completed': completed ? 1 : 0,
      'updatedAt': now,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<Task?> getTask(int id) async {
    final rows = await db.query('tasks', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Task.fromMap(rows.first);
  }

  /// 未删除任务。includeCompleted 决定是否含已完成。
  Future<List<Task>> queryAll({bool includeCompleted = true}) async {
    final rows = await db.query('tasks',
        where: 'deletedAt IS NULL'
            '${includeCompleted ? '' : ' AND completed = 0'}',
        orderBy: 'sortOrder ASC, id ASC');
    return rows.map(Task.fromMap).toList();
  }

  /// 今天视图：到期日=今天 或（过期且未完成）
  Future<List<Task>> queryToday({required String today}) async {
    final rows = await db.query('tasks',
        where:
            'deletedAt IS NULL AND (dueDate = ? OR (dueDate IS NOT NULL AND dueDate < ? AND completed = 0))',
        whereArgs: [today, today],
        orderBy: 'completed ASC, priority DESC, dueDate ASC, id ASC');
    return rows.map(Task.fromMap).toList();
  }

  /// 最近7天视图：[start, start+6]，未完成 + 已完成（今天完成的也显示在周视图？只显示未完成+今天完成的）
  Future<List<Task>> queryWeek({required String start, required String end}) async {
    final rows = await db.query('tasks',
        where: 'deletedAt IS NULL AND dueDate >= ? AND dueDate <= ?',
        whereArgs: [start, end],
        orderBy: 'completed ASC, priority DESC, dueDate ASC, id ASC');
    return rows.map(Task.fromMap).toList();
  }

  /// 全部已完成任务（折叠区）
  Future<List<Task>> queryCompleted() async {
    final rows = await db.query('tasks',
        where: 'deletedAt IS NULL AND completed = 1',
        orderBy: 'updatedAt DESC');
    return rows.map(Task.fromMap).toList();
  }

  Future<List<Task>> queryByList(int listId) async {
    final rows = await db.query('tasks',
        where: 'deletedAt IS NULL AND listId = ?', whereArgs: [listId],
        orderBy: 'completed ASC, priority DESC, dueDate ASC, id ASC');
    return rows.map(Task.fromMap).toList();
  }

  Future<List<Task>> queryByDate(String date) async {
    final rows = await db.query('tasks',
        where: 'deletedAt IS NULL AND dueDate = ?', whereArgs: [date],
        orderBy: 'completed ASC, priority DESC, id ASC');
    return rows.map(Task.fromMap).toList();
  }

  Future<List<Task>> queryByTags(List<int> tagIds) async {
    if (tagIds.isEmpty) return const [];
    final ph = List.filled(tagIds.length, '?').join(',');
    final rows = await db.rawQuery('''
      SELECT DISTINCT t.* FROM tasks t
      JOIN task_tags tt ON tt.taskId = t.id
      WHERE t.deletedAt IS NULL AND tt.tagId IN ($ph)
      ORDER BY t.completed ASC, t.priority DESC, t.id ASC
    ''', tagIds);
    return rows.map(Task.fromMap).toList();
  }

  // ---------- 子任务 ----------

  Future<int?> upsertSubtask(Subtask s) async {
    final now = _now();
    final st = s.copyWith(updatedAt: now, createdAt: s.createdAt ?? now);
    if (st.id == null) {
      final id = await db.insert('subtasks', st.toMap()..remove('id'));
      return id;
    }
    await db.update('subtasks', st.toMap(),
        where: 'id = ?', whereArgs: [st.id]);
    return st.id;
  }

  Future<void> bulkUpsertSubtasks(List<Subtask> subs) async {
    final now = _now();
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final s in subs) {
        final st =
            s.copyWith(updatedAt: now, createdAt: s.createdAt ?? now);
        if (st.id == null) {
          batch.insert('subtasks', st.toMap()..remove('id'));
        } else {
          batch.insert('subtasks', st.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> softDeleteSubtask(int id) async {
    final now = _now();
    await db.update('subtasks', {'deletedAt': now, 'updatedAt': now},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> toggleSubtask(int id, bool completed) async {
    final now = _now();
    await db.update('subtasks', {
      'completed': completed ? 1 : 0,
      'updatedAt': now,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Subtask>> subtasksOf(int taskId) async {
    final rows = await db.query('subtasks',
        where: 'taskId = ? AND deletedAt IS NULL', whereArgs: [taskId],
        orderBy: 'sortOrder ASC, id ASC');
    return rows.map(Subtask.fromMap).toList();
  }
}
