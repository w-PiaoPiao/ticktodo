import 'package:sqflite/sqflite.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/habit.dart';

/// 习惯打卡数据访问 + 统计。
class HabitRepository {
  HabitRepository(this._appDb);

  final AppDatabase _appDb;
  Database get db => _appDb.db;

  int _now() => DateTime.now().millisecondsSinceEpoch;

  // ---------- 习惯 CRUD ----------

  Future<int?> upsertHabit(Habit habit) async {
    final now = _now();
    final h = habit.copyWith(updatedAt: now, createdAt: habit.createdAt ?? now);
    if (h.id == null) {
      final id = await db.insert('habits', h.toMap()..remove('id'));
      return id;
    }
    await db
        .update('habits', h.toMap(), where: 'id = ?', whereArgs: [h.id]);
    return h.id;
  }

  /// 归档（不再出现在今日列表，但保留历史）。
  Future<void> archiveHabit(int id, {bool archived = true}) async {
    final now = _now();
    await db.update('habits', {'archived': archived ? 1 : 0, 'updatedAt': now},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> softDeleteHabit(int id) async {
    final now = _now();
    await db.update('habits', {'deletedAt': now, 'updatedAt': now},
        where: 'id = ?', whereArgs: [id]);
    await db.update('habit_checks', {'deletedAt': now, 'updatedAt': now},
        where: 'habitId = ? AND deletedAt IS NULL', whereArgs: [id]);
  }

  Future<List<Habit>> queryHabits({bool includeArchived = false}) async {
    final rows = await db.query('habits',
        where: 'deletedAt IS NULL'
            '${includeArchived ? '' : ' AND archived = 0'}',
        orderBy: 'sortOrder ASC, id ASC');
    return rows.map(Habit.fromMap).toList();
  }

  // ---------- 打卡 ----------

  /// 切换某习惯某天的打卡状态，返回切换后是否已打勾。
  Future<bool> toggleCheck(int habitId, String date) async {
    final now = _now();
    final existing = await db.query('habit_checks',
        where: 'habitId = ? AND date = ?', whereArgs: [habitId, date],
        limit: 1);
    if (existing.isEmpty) {
      await db.insert(
          'habit_checks',
          HabitCheck(habitId: habitId, date: date, createdAt: now, updatedAt: now)
              .toMap()
            ..remove('id'));
      return true;
    }
    final row = existing.first;
    if (row['deletedAt'] == null) {
      await db.update('habit_checks', {'deletedAt': now, 'updatedAt': now},
          where: 'id = ?', whereArgs: [row['id']]);
      return false;
    }
    await db.update('habit_checks', {'deletedAt': null, 'updatedAt': now},
        where: 'id = ?', whereArgs: [row['id']]);
    return true;
  }

  /// 某习惯在 [start, end] 日期区间内已打卡的日期集合。
  Future<Set<String>> checkedDates(int habitId,
      {required String start, required String end}) async {
    final rows = await db.query('habit_checks',
        columns: ['date'],
        where:
            'habitId = ? AND deletedAt IS NULL AND date >= ? AND date <= ?',
        whereArgs: [habitId, start, end]);
    return rows.map((r) => r['date'] as String).toSet();
  }

  /// 指定日期的打卡记录是否存在。
  Future<bool> isCheckedOn(int habitId, String date) async {
    final rows = await db.query('habit_checks',
        where:
            'habitId = ? AND date = ? AND deletedAt IS NULL',
        whereArgs: [habitId, date],
        limit: 1);
    return rows.isNotEmpty;
  }

  // ---------- 统计 ----------

  /// 连续打卡天数：从今天往前数（今天未打卡则从昨天起算），遇断档停止。
  Future<int> currentStreak(int habitId, {DateTime? now}) async {
    final n = now ?? DateTime.now();
    var cursor =
        DateTime(n.year, n.month, n.day); // 今天 00:00
    // 今天还没打卡不中断连续，从昨天开始数
    final todayStr = DateUtilsEx.formatDate(cursor);
    if (!await isCheckedOn(habitId, todayStr)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (true) {
      final d = DateUtilsEx.formatDate(cursor);
      if (await isCheckedOn(habitId, d)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
        // 防御上限：最多回溯 10 年
        if (streak > 3650) break;
      } else {
        break;
      }
    }
    return streak;
  }

  /// 累计打卡总次数。
  Future<int> totalChecks(int habitId) async {
    final rows = await db.query('habit_checks',
        where: 'habitId = ? AND deletedAt IS NULL',
        whereArgs: [habitId]);
    return rows.length;
  }

  /// 本周（周一起）已打卡天数。
  Future<int> weekCheckCount(int habitId, {DateTime? now}) async {
    final n = now ?? DateTime.now();
    final monday = DateTime(n.year, n.month, n.day)
        .subtract(Duration(days: n.weekday - 1));
    final dates = await checkedDates(habitId,
        start: DateUtilsEx.formatDate(monday),
        end: DateUtilsEx.formatDate(n));
    return dates.length;
  }
}
