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

  /// 习惯页批量加载：一次取习惯列表 + 一次取全部有效打卡日期，
  /// 在内存派生 今日打卡/连续天数/本周次数/近 5 周日期。
  /// 替代旧实现每个习惯 4 次串行查询（4N+1 → 2 次）。
  Future<List<HabitWithStats>> habitsWithStats(
      {bool includeArchived = false, DateTime? now}) async {
    final n = now ?? DateTime.now();
    final habits = await queryHabits(includeArchived: includeArchived);
    if (habits.isEmpty) return const [];

    final ids = [for (final h in habits) if (h.id != null) h.id!];
    final rows = await db.query('habit_checks',
        columns: ['habitId', 'date'],
        where:
            'deletedAt IS NULL AND habitId IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: ids);
    final byHabit = <int, Set<String>>{};
    for (final r in rows) {
      byHabit
          .putIfAbsent(r['habitId'] as int, () => {})
          .add(r['date'] as String);
    }

    final today = DateTime(n.year, n.month, n.day);
    final todayStr = DateUtilsEx.formatDate(today);
    final monday = today.subtract(Duration(days: n.weekday - 1));
    final weekStartStr = DateUtilsEx.formatDate(monday);
    final weekEndStr =
        DateUtilsEx.formatDate(monday.add(const Duration(days: 6)));
    final recentStartStr =
        DateUtilsEx.formatDate(today.subtract(const Duration(days: 34)));

    final result = <HabitWithStats>[];
    for (final h in habits) {
      final id = h.id;
      final dates = (id == null ? null : byHabit[id]) ?? const <String>{};
      // 连续天数：从今天往前回溯（今天未打卡不中断，从昨天起算）
      var streak = 0;
      var cursor = today;
      if (!dates.contains(DateUtilsEx.formatDate(cursor))) {
        cursor = cursor.subtract(const Duration(days: 1));
      }
      while (dates.contains(DateUtilsEx.formatDate(cursor))) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
        if (streak > 3650) break;
      }
      var weekCount = 0;
      final recent = <String>{};
      for (final d in dates) {
        if (d.compareTo(weekStartStr) >= 0 && d.compareTo(weekEndStr) <= 0) {
          weekCount++;
        }
        if (d.compareTo(recentStartStr) >= 0) recent.add(d);
      }
      result.add(HabitWithStats(
        habit: h,
        checkedToday: dates.contains(todayStr),
        streak: streak,
        weekCount: weekCount,
        recentDates: recent,
      ));
    }
    return result;
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
    // 一次拉取全部打卡日期，内存中回溯，避免逐天 N+1 查询
    final rows = await db.query('habit_checks',
        columns: ['date'],
        where: 'habitId = ? AND deletedAt IS NULL',
        whereArgs: [habitId]);
    final checked = rows.map((r) => r['date'] as String).toSet();

    var cursor = DateTime(n.year, n.month, n.day); // 今天 00:00
    // 今天还没打卡不中断连续，从昨天开始数
    if (!checked.contains(DateUtilsEx.formatDate(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (checked.contains(DateUtilsEx.formatDate(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
      // 防御上限：最多回溯 10 年
      if (streak > 3650) break;
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

  /// 物理清理软删超过 [olderThanMs] 毫秒的习惯与打卡记录，返回清理行数。
  Future<int> purgeDeleted({int olderThanMs = 0}) async {
    final cutoff = DateTime.now().millisecondsSinceEpoch - olderThanMs;
    final habits = await db.delete('habits',
        where: 'deletedAt IS NOT NULL AND deletedAt <= ?',
        whereArgs: [cutoff]);
    // 打卡记录可能因习惯已硬删而成为孤儿，一并按自身 deletedAt 清理。
    // 括号必要：A AND B OR C 会按 (A AND B) OR C 解析，孤儿记录将无视时限被立即删。
    final checks = await db.delete('habit_checks',
        where:
            '(deletedAt IS NOT NULL AND deletedAt <= ?) '
            'OR habitId NOT IN (SELECT id FROM habits)',
        whereArgs: [cutoff]);
    return habits + checks;
  }
}

/// 习惯卡片所需的聚合数据（[HabitRepository.habitsWithStats] 的结果行）。
class HabitWithStats {
  const HabitWithStats({
    required this.habit,
    required this.checkedToday,
    required this.streak,
    required this.weekCount,
    required this.recentDates,
  });

  final Habit habit;
  final bool checkedToday;
  final int streak;
  final int weekCount;

  /// 近 5 周打卡日期（热力图）。
  final Set<String> recentDates;
}
