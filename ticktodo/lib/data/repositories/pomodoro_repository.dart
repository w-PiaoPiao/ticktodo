import 'package:sqflite/sqflite.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/habit.dart';

/// 番茄专注会话数据访问 + 统计。
class PomodoroRepository {
  PomodoroRepository(this._appDb);

  final AppDatabase _appDb;
  Database get db => _appDb.db;

  int _now() => DateTime.now().millisecondsSinceEpoch;

  Future<int?> saveSession(PomodoroSession session) async {
    final now = _now();
    final s = session.copyWith(
        updatedAt: now, createdAt: session.createdAt ?? now);
    if (s.id == null) {
      final id = await db.insert('pomodoros', s.toMap()..remove('id'));
      return id;
    }
    await db.update('pomodoros', s.toMap(),
        where: 'id = ?', whereArgs: [s.id]);
    return s.id;
  }

  /// 最近会话（含放弃），按开始时间倒序。
  Future<List<PomodoroSession>> recentSessions({int limit = 50}) async {
    final rows = await db.query('pomodoros',
        where: 'deletedAt IS NULL',
        orderBy: 'startedAt DESC',
        limit: limit);
    return rows.map(PomodoroSession.fromMap).toList();
  }

  /// 今日完成的番茄数。
  Future<int> todayCount({DateTime? now}) async {
    final n = now ?? DateTime.now();
    final start = DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
    final rows = await db.query('pomodoros',
        where: 'deletedAt IS NULL AND completed = 1 AND startedAt >= ?',
        whereArgs: [start]);
    return rows.length;
  }

  /// 今日累计专注分钟数（仅完成会话）。
  Future<int> todayMinutes({DateTime? now}) async {
    final n = now ?? DateTime.now();
    final start = DateTime(n.year, n.month, n.day).millisecondsSinceEpoch;
    final rows = await db.query('pomodoros',
        columns: ['durationMinutes'],
        where: 'deletedAt IS NULL AND completed = 1 AND startedAt >= ?',
        whereArgs: [start]);
    return rows.fold<int>(0, (sum, r) => sum + (r['durationMinutes'] as int));
  }

  /// 近 N 天每日完成数（日期 → 数量），用于柱状统计。
  Future<Map<String, int>> dailyCounts(int days, {DateTime? now}) async {
    final n = now ?? DateTime.now();
    final startDay =
        DateTime(n.year, n.month, n.day).subtract(Duration(days: days - 1));
    final rows = await db.query('pomodoros',
        columns: ['startedAt'],
        where: 'deletedAt IS NULL AND completed = 1 AND startedAt >= ?',
        whereArgs: [startDay.millisecondsSinceEpoch]);
    final result = <String, int>{};
    for (var i = 0; i < days; i++) {
      result[DateUtilsEx.formatDate(startDay.add(Duration(days: i)))] = 0;
    }
    for (final r in rows) {
      final d = DateUtilsEx.formatDate(
          DateTime.fromMillisecondsSinceEpoch(r['startedAt'] as int));
      result[d] = (result[d] ?? 0) + 1;
    }
    return result;
  }

  /// 物理清理软删超过 [olderThanMs] 毫秒的会话记录，返回清理行数。
  Future<int> purgeDeleted({int olderThanMs = 0}) async {
    final cutoff = DateTime.now().millisecondsSinceEpoch - olderThanMs;
    return db.delete('pomodoros',
        where: 'deletedAt IS NOT NULL AND deletedAt <= ?',
        whereArgs: [cutoff]);
  }
}
