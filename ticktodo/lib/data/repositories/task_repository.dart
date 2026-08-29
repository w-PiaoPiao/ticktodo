import 'package:sqflite/sqflite.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/core/repeat_rule.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/reminder.dart';
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

  /// 完成（可能重复的）任务：原任务置为已完成；
  /// 若设置了重复规则且有到期日，克隆生成下一期未完成任务
  /// （子任务/标签关联同步克隆，提醒保持相对偏移），返回下一期；
  /// 否则返回 null（仅完成）。
  Future<Task?> completeAndAdvance(int taskId) async {
    final now = _now();
    return db.transaction((txn) async {
      final rows = await txn.query('tasks', where: 'id = ?', whereArgs: [taskId]);
      if (rows.isEmpty) return null;
      final task = Task.fromMap(rows.first);
      if (task.completed) return null;

      await txn.update('tasks', {'completed': 1, 'updatedAt': now},
          where: 'id = ?', whereArgs: [taskId]);

      final rule = RepeatRule.parse(task.repeatRule);
      if (rule == null || task.dueDate == null) return null;

      final baseDate = DateUtilsEx.parseDate(task.dueDate!);
      final nextDate = rule.nextDue(baseDate);

      // 提醒保持"挂钟偏移"：按日历天数 + 当日分钟数计算，跨 DST 不漂移；
      // 全天任务（无 dueTime）也保留提醒，dueTime 脏数据不中断完成操作
      final dueMinuteOfDay = _parseHmMinutes(task.dueTime) ?? 0;
      int? nextRemindAt;
      final oldRemindAt = task.remindAt;
      if (oldRemindAt != null) {
        final offsetMin =
            _remindOffsetMinutes(baseDate, dueMinuteOfDay, oldRemindAt);
        nextRemindAt = _applyRemindOffset(nextDate, dueMinuteOfDay, offsetMin);
      }

      // 注意：copyWith 无法清空 id（id ?? this.id），克隆必须手动构造。
      final next = Task(
        title: task.title,
        note: task.note,
        priority: task.priority,
        dueDate: DateUtilsEx.formatDate(nextDate),
        dueTime: task.dueTime,
        remindAt: nextRemindAt,
        listId: task.listId,
        sortOrder: task.sortOrder,
        createdAt: now,
        updatedAt: now,
      );

      final newId = await txn.insert('tasks', next.toMap()..remove('id'));

      // 克隆子任务（全部重置为未完成）
      final subs = await txn.query('subtasks',
          where: 'taskId = ? AND deletedAt IS NULL', whereArgs: [taskId]);
      for (final s in subs) {
        final sm = Subtask.fromMap(s);
        final clone = Subtask(
          taskId: newId,
          title: sm.title,
          sortOrder: sm.sortOrder,
          createdAt: now,
          updatedAt: now,
        );
        await txn.insert('subtasks', clone.toMap()..remove('id'));
      }

      // 克隆标签关联（只克隆未取消的，新关联带 updatedAt 参与同步合并）
      final links = await txn.query('task_tags',
          where: 'taskId = ? AND deletedAt IS NULL', whereArgs: [taskId]);
      for (final l in links) {
        await txn.insert('task_tags',
            {'taskId': newId, 'tagId': l['tagId'] as int, 'updatedAt': now},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      // 克隆额外提醒（应用同样的挂钟偏移；全天任务原来会整段丢失提醒，一并修复）
      final oldReminders = await txn.query('reminders',
          where: 'taskId = ? AND deletedAt IS NULL', whereArgs: [taskId]);
      for (final r in oldReminders) {
        final offsetMin = _remindOffsetMinutes(
            baseDate, dueMinuteOfDay, r['remindAt'] as int);
        await txn.insert('reminders', {
          'taskId': newId,
          'remindAt': _applyRemindOffset(nextDate, dueMinuteOfDay, offsetMin),
          'createdAt': now,
          'updatedAt': now,
        });
      }

      final out = await txn.query('tasks', where: 'id = ?', whereArgs: [newId]);
      return Task.fromMap(out.first);
    });
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
      WHERE t.deletedAt IS NULL AND tt.deletedAt IS NULL AND tt.tagId IN ($ph)
      ORDER BY t.completed ASC, t.priority DESC, t.id ASC
     ''', tagIds);
    return rows.map(Task.fromMap).toList();
  }

  /// 全局搜索：标题或备注包含关键词（大小写不敏感），排除已删除。
  Future<List<Task>> searchTasks(String keyword) async {
    final kw = '%${keyword.trim()}%';
    if (kw == '%%') return const [];
    final rows = await db.query('tasks',
        where:
            "deletedAt IS NULL AND (title LIKE ? COLLATE NOCASE OR note LIKE ? COLLATE NOCASE)",
        whereArgs: [kw, kw],
        orderBy: 'completed ASC, priority DESC, dueDate ASC, id ASC');
    return rows.map(Task.fromMap).toList();
  }

  // ---------- 批量操作 ----------

  String _placeholders(int n) => List.filled(n, '?').join(',');

  Future<void> bulkSoftDelete(List<int> ids) async {
    if (ids.isEmpty) return;
    final now = _now();
    await db.update('tasks', {'deletedAt': now, 'updatedAt': now},
        where: 'id IN (${_placeholders(ids.length)})', whereArgs: ids);
  }

  Future<void> bulkMoveToList(List<int> ids, int listId) async {
    if (ids.isEmpty) return;
    final now = _now();
    await db.update('tasks', {'listId': listId, 'updatedAt': now},
        where: 'id IN (${_placeholders(ids.length)})', whereArgs: ids);
  }

  Future<void> bulkSetDueDate(List<int> ids, String? date) async {
    if (ids.isEmpty) return;
    final now = _now();
    await db.update('tasks', {'dueDate': date, 'updatedAt': now},
        where: 'id IN (${_placeholders(ids.length)})', whereArgs: ids);
  }

  /// 各清单的未删除任务数（单条 GROUP BY 查询，替代逐清单 count）。
  Future<Map<int, int>> taskCountsByList() async {
    final rows = await db.rawQuery(
        'SELECT listId, COUNT(*) AS c FROM tasks '
        'WHERE deletedAt IS NULL GROUP BY listId');
    return {for (final r in rows) r['listId'] as int: r['c'] as int};
  }

  // ---------- 回收站 ----------

  /// 所有软删除任务，按删除时间倒序。
  Future<List<Task>> queryDeleted() async {
    final rows = await db.query('tasks',
        where: 'deletedAt IS NOT NULL', orderBy: 'deletedAt DESC');
    return rows.map(Task.fromMap).toList();
  }

  /// 彻底删除任务及其子任务、标签关联、额外提醒。
  Future<void> hardDeleteTasks(List<int> ids) async {
    if (ids.isEmpty) return;
    final ph = _placeholders(ids.length);
    await db.transaction((txn) async {
      await txn.delete('subtasks', where: 'taskId IN ($ph)', whereArgs: ids);
      await txn.delete('task_tags', where: 'taskId IN ($ph)', whereArgs: ids);
      await txn.delete('reminders', where: 'taskId IN ($ph)', whereArgs: ids);
      await txn.delete('tasks', where: 'id IN ($ph)', whereArgs: ids);
    });
  }

  /// 清理已彻底过期（deletedAt 早于 olderThanMs 毫秒前）的回收站任务，返回清理数量。
  /// 顺带清理过期的标签关联墓碑（task_tags.deletedAt），防止无限累积；
  /// 墓碑保留期应覆盖"其他设备最长离线时长"，见 kTombstoneRetention。
  Future<int> purgeDeleted({int olderThanMs = 0}) async {
    final cutoff = DateTime.now().millisecondsSinceEpoch - olderThanMs;
    await db.delete('task_tags',
        where: 'deletedAt IS NOT NULL AND deletedAt <= ?', whereArgs: [cutoff]);
    final rows = await db.query('tasks',
        columns: ['id'],
        where: 'deletedAt IS NOT NULL AND deletedAt <= ?',
        whereArgs: [cutoff]);
    if (rows.isEmpty) return 0;
    final ids = rows.map((r) => r['id'] as int).toList();
    await hardDeleteTasks(ids);
    return ids.length;
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

  // ---------- 额外提醒时间 ----------

  /// 任务的额外提醒（按时间升序）。
  Future<List<Reminder>> queryRemindersOf(int taskId) async {
    final rows = await db.query('reminders',
        where: 'taskId = ? AND deletedAt IS NULL', whereArgs: [taskId],
        orderBy: 'remindAt ASC');
    return rows.map(Reminder.fromMap).toList();
  }

  /// 全量替换任务的额外提醒（软删旧行 + 插入新行）。
  Future<void> setReminders(int taskId, List<int> epochs) async {
    final now = _now();
    await db.transaction((txn) async {
      await txn.update('reminders', {'deletedAt': now, 'updatedAt': now},
          where: 'taskId = ? AND deletedAt IS NULL', whereArgs: [taskId]);
      for (final e in epochs) {
        await txn.insert('reminders', {
          'taskId': taskId,
          'remindAt': e,
          'createdAt': now,
          'updatedAt': now,
        });
      }
    });
  }

  /// 软删除任务的全部额外提醒。
  Future<void> clearReminders(int taskId) async {
    final now = _now();
    await db.update('reminders', {'deletedAt': now, 'updatedAt': now},
        where: 'taskId = ? AND deletedAt IS NULL', whereArgs: [taskId]);
  }
}

/// 'HH:mm' → 当日分钟数；格式非法返回 null（调用方兜底，不抛异常中断完成操作）。
int? _parseHmMinutes(String? hm) {
  if (hm == null) return null;
  final parts = hm.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0].trim());
  final m = int.tryParse(parts[1].trim());
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

/// 提醒相对到期日 00:00 的"挂钟偏移"（分钟，可为负/跨天）。
/// 用日历天数 + 当日分钟数表达，跨 DST 边界不会像 epoch 差那样漂移 1 小时。
int _remindOffsetMinutes(DateTime dueDate, int dueMinuteOfDay, int remindAtMs) {
  final remind = DateTime.fromMillisecondsSinceEpoch(remindAtMs);
  final dayGap = DateTime.utc(remind.year, remind.month, remind.day)
      .difference(DateTime.utc(dueDate.year, dueDate.month, dueDate.day))
      .inDays;
  return dayGap * 1440 + remind.hour * 60 + remind.minute - dueMinuteOfDay;
}

/// 把挂钟偏移应用到新到期日，返回新提醒时刻（毫秒）。
/// 用 DateTime(y,m,d,h,min) 墙钟构造，而非 epoch 加减。
int _applyRemindOffset(DateTime nextDueDate, int dueMinuteOfDay, int offsetMin) {
  final total = dueMinuteOfDay + offsetMin;
  final minuteOfDay = total % 1440; // Dart 的 % 恒非负
  final dayShift = (total - minuteOfDay) ~/ 1440;
  final d = DateTime(
      nextDueDate.year, nextDueDate.month, nextDueDate.day + dayShift);
  return DateTime(d.year, d.month, d.day, minuteOfDay ~/ 60, minuteOfDay % 60)
      .millisecondsSinceEpoch;
}
