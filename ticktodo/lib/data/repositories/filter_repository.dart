import 'package:sqflite/sqflite.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/filter.dart';
import 'package:ticktodo/data/models/task.dart';

/// 自定义过滤器（智能清单）CRUD 与任务匹配查询。
class FilterRepository {
  FilterRepository(this._appDb);

  final AppDatabase _appDb;
  Database get db => _appDb.db;

  int _now() => DateTime.now().millisecondsSinceEpoch;

  // ---------- CRUD ----------

  Future<int?> upsertFilter(Filter filter) async {
    final now = _now();
    final f = filter.copyWith(updatedAt: now, createdAt: filter.createdAt ?? now);
    if (f.id == null) {
      final id = await db.insert('filters', f.toMap()..remove('id'));
      return id;
    }
    await db.update('filters', f.toMap(), where: 'id = ?', whereArgs: [f.id]);
    return f.id;
  }

  Future<void> softDeleteFilter(int id) async {
    final now = _now();
    await db.update('filters', {'deletedAt': now, 'updatedAt': now},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Filter>> queryFilters() async {
    final rows = await db.query('filters',
        where: 'deletedAt IS NULL',
        orderBy: 'sortOrder ASC, id ASC');
    return rows.map(Filter.fromMap).toList();
  }

  // ---------- 匹配查询 ----------

  /// 按过滤器组合查询未完成任务。
  Future<List<Task>> queryTasksByFilter(Filter filter) async {
    final today = DateUtilsEx.formatDate(DateTime.now());
    final end = DateUtilsEx.formatDate(
        DateTime.now().add(const Duration(days: 6)));

    var where = 't.deletedAt IS NULL AND t.completed = 0';
    final args = <Object?>[];

    switch (filter.dateMode) {
      case FilterDateMode.today:
        where += ' AND t.dueDate = ?';
        args.add(today);
      case FilterDateMode.week:
        where += ' AND t.dueDate >= ? AND t.dueDate <= ?';
        args..add(today)..add(end);
      case FilterDateMode.overdue:
        where += ' AND t.dueDate IS NOT NULL AND t.dueDate < ?';
        args.add(today);
      case FilterDateMode.noDate:
        where += ' AND t.dueDate IS NULL';
      case FilterDateMode.any:
        break;
    }

    if (filter.minPriority > 0) {
      where += ' AND t.priority >= ?';
      args.add(filter.minPriority);
    }

    if (filter.listIds.isNotEmpty) {
      final ph = List.filled(filter.listIds.length, '?').join(',');
      where += ' AND t.listId IN ($ph)';
      args.addAll(filter.listIds);
    }

    if (filter.tagIds.isNotEmpty) {
      final ph = List.filled(filter.tagIds.length, '?').join(',');
      where +=
          ' AND EXISTS (SELECT 1 FROM task_tags tt WHERE tt.taskId = t.id AND tt.tagId IN ($ph))';
      args.addAll(filter.tagIds);
    }

    final rows = await db.query('tasks AS t',
        where: where,
        whereArgs: args,
        orderBy:
            't.completed ASC, t.priority DESC, t.dueDate ASC, t.id ASC');
    return rows.map(Task.fromMap).toList();
  }
}
