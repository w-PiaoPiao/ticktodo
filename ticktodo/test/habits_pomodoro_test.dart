import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/habit.dart';
import 'package:ticktodo/data/repositories/habit_repository.dart';
import 'package:ticktodo/data/repositories/pomodoro_repository.dart';
import 'package:ticktodo/sync/snapshot.dart';
import 'package:ticktodo/sync/snapshot_merge.dart';

void main() {
  late AppDatabase appDb;
  late HabitRepository habits;
  late PomodoroRepository pomodoros;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    appDb = await AppDatabase.open(inMemoryPath: inMemoryDatabasePath);
    habits = HabitRepository(appDb);
    pomodoros = PomodoroRepository(appDb);
  });

  tearDown(() async {
    await appDb.db.close();
  });

  group('习惯 CRUD', () {
    test('创建并查询', () async {
      await habits.upsertHabit(
          const Habit(name: '阅读', color: 0xFF4C9AFF, targetDays: 5));
      final list = await habits.queryHabits();
      expect(list.length, 1);
      expect(list.first.name, '阅读');
      expect(list.first.targetDays, 5);
    });

    test('归档后默认列表不显示', () async {
      final id =
          (await habits.upsertHabit(const Habit(name: '晨跑')))!;
      await habits.archiveHabit(id);
      expect((await habits.queryHabits()), isEmpty);
      expect((await habits.queryHabits(includeArchived: true)).length, 1);
    });

    test('软删除级联清掉打卡记录', () async {
      final id = (await habits.upsertHabit(const Habit(name: '冥想')))!;
      await habits.toggleCheck(id, '2026-08-22');
      await habits.softDeleteHabit(id);
      expect(await habits.queryHabits(), isEmpty);
      final checks = await appDb.db
          .query('habit_checks', where: 'habitId = ?', whereArgs: [id]);
      // 记录行还在但已软删
      expect(checks.every((r) => r['deletedAt'] != null), isTrue);
    });
  });

  group('打卡', () {
    test('toggleCheck 三连切换：勾→取消→再勾', () async {
      final id = (await habits.upsertHabit(const Habit(name: '喝水')))!;
      expect(await habits.toggleCheck(id, '2026-08-22'), isTrue);
      expect(await habits.toggleCheck(id, '2026-08-22'), isFalse);
      expect(await habits.toggleCheck(id, '2026-08-22'), isTrue);
      // UNIQUE(habitId,date) 保证只有一行
      final rows = await appDb.db.query('habit_checks',
          where: 'habitId = ?', whereArgs: [id]);
      expect(rows.length, 1);
    });

    test('checkedDates 区间过滤', () async {
      final id = (await habits.upsertHabit(const Habit(name: '背单词')))!;
      await habits.toggleCheck(id, '2026-08-01');
      await habits.toggleCheck(id, '2026-08-22');
      await habits.toggleCheck(id, '2026-07-15');

      final dates = await habits.checkedDates(id,
          start: '2026-08-01', end: '2026-08-31');
      expect(dates, {'2026-08-01', '2026-08-22'});
    });
  });

  group('连续天数 streak', () {
    final base = DateTime(2026, 8, 22); // 周六

    Future<void> checkOn(String date) async {
      final id = 1; // 由调用方先建习惯
      await habits.toggleCheck(id, date);
    }

    test('今天+昨天+前天 → 连续 3 天', () async {
      await habits.upsertHabit(const Habit(name: 'h'));
      await checkOn('2026-08-22');
      await checkOn('2026-08-21');
      await checkOn('2026-08-20');
      expect(await habits.currentStreak(1, now: base), 3);
    });

    test('今天没打但昨天前天打了 → 不中断，计 2', () async {
      await habits.upsertHabit(const Habit(name: 'h'));
      await checkOn('2026-08-21');
      await checkOn('2026-08-20');
      expect(await habits.currentStreak(1, now: base), 2);
    });

    test('昨天断档 → 只算今天 1 天', () async {
      await habits.upsertHabit(const Habit(name: 'h'));
      await checkOn('2026-08-22');
      await checkOn('2026-08-20'); // 昨天缺
      expect(await habits.currentStreak(1, now: base), 1);
    });

    test('全没打卡 → 0', () async {
      await habits.upsertHabit(const Habit(name: 'h'));
      expect(await habits.currentStreak(1, now: base), 0);
    });
  });

  group('统计', () {
    test('totalChecks 与 weekCheckCount', () async {
      await habits.upsertHabit(const Habit(name: 'h'));
      // 2026-08-17(周一) ~ 2026-08-23(周日) 是同一周
      for (final d in ['2026-08-18', '2026-08-19', '2026-08-22']) {
        await habits.toggleCheck(1, d);
      }
      await habits.toggleCheck(1, '2026-07-01');

      expect(await habits.totalChecks(1), 4);
      expect(await habits.weekCheckCount(1, now: DateTime(2026, 8, 22)), 3);
    });
  });

  group('番茄会话', () {
    PomodoroSession session(int startedAt,
            {int minutes = 25, bool completed = true}) =>
        PomodoroSession(
          taskId: null,
          taskTitle: '',
          startedAt: startedAt,
          durationMinutes: minutes,
          completed: completed,
        );

    test('todayCount/todayMinutes 只统计今天完成的', () async {
      final dayStart = DateTime(2026, 8, 22).millisecondsSinceEpoch;
      await pomodoros.saveSession(session(dayStart + 3600000)); // 今天 完成
      await pomodoros.saveSession(session(dayStart + 7200000)); // 今天 完成
      await pomodoros.saveSession(session(dayStart + 10800000,
          completed: false)); // 今天 放弃
      await pomodoros.saveSession(
          session(DateTime(2026, 8, 21).millisecondsSinceEpoch)); // 昨天

      expect(await pomodoros.todayCount(now: DateTime(2026, 8, 22)), 2);
      expect(await pomodoros.todayMinutes(now: DateTime(2026, 8, 22)), 50);
    });

    test('recentSessions 按开始时间倒序', () async {
      await pomodoros.saveSession(session(1000));
      await pomodoros.saveSession(session(3000));
      await pomodoros.saveSession(session(2000));

      final list = await pomodoros.recentSessions();
      expect(list.map((s) => s.startedAt).toList(), [3000, 2000, 1000]);
    });

    test('dailyCounts 分布到近 N 天', () async {
      await pomodoros.saveSession(
          session(DateTime(2026, 8, 22, 10).millisecondsSinceEpoch));
      await pomodoros.saveSession(
          session(DateTime(2026, 8, 22, 11).millisecondsSinceEpoch));
      await pomodoros.saveSession(
          session(DateTime(2026, 8, 21, 9).millisecondsSinceEpoch));

      final counts = await pomodoros.dailyCounts(3, now: DateTime(2026, 8, 22));
      expect(counts['2026-08-22'], 2);
      expect(counts['2026-08-21'], 1);
      expect(counts['2026-08-20'], 0);
    });
  });

  group('快照 v4 扩展', () {
    test('buildSnapshot 包含习惯数据且 JSON 往返', () async {
      await habits.upsertHabit(const Habit(name: '跑步', color: 0xFF4C9AFF));
      await habits.toggleCheck(1, '2026-08-22');
      await pomodoros.saveSession(PomodoroSession(
        taskTitle: '写作',
        startedAt: 1755800000000,
        durationMinutes: 25,
        completed: true,
      ));

      final snap = await buildSnapshot(appDb, 200);
      expect(snap.habits.map((h) => h.name), contains('跑步'));
      expect(snap.habitChecks.map((c) => c.date), contains('2026-08-22'));
      expect(snap.pomodoros.map((p) => p.taskTitle), contains('写作'));

      final json = jsonDecode(jsonEncode(snap.toJson())) as Map<String, dynamic>;
      final restored = SyncSnapshot.fromJson(json);
      expect(restored.habits.first.name, '跑步');
      expect(restored.habitChecks.first.date, '2026-08-22');
      expect(restored.pomodoros.first.completed, isTrue);
    });

    test('applySnapshot 替换式写入习惯数据', () async {
      await habits.upsertHabit(const Habit(name: '本地的'));

      final snap = SyncSnapshot(
        revision: 30,
        tasks: const [],
        subtasks: const [],
        lists: const [],
        tags: const [],
        taskTags: const [],
        reminders: const [],
        filters: const [],
        habits: [const Habit(id: 9, name: '远端习惯', updatedAt: 7)],
        habitChecks: [
          const HabitCheck(id: 91, habitId: 9, date: '2026-08-20', updatedAt: 7),
        ],
        pomodoros: [
          PomodoroSession(id: 92, startedAt: 111, updatedAt: 7),
        ],
      );
      await applySnapshot(appDb, snap);

      final names = (await habits.queryHabits()).map((h) => h.name).toSet();
      expect(names, {'远端习惯'});
      final checks = await appDb.db.query('habit_checks');
      expect(checks.length, 1);
      expect(checks.first['date'], '2026-08-20');
      final poms = await appDb.db.query('pomodoros');
      expect(poms.length, 1);
    });

    test('mergeSnapshots 按 updatedAt 合并习惯', () {
      final local = SyncSnapshot(revision: 1, tasks: const [], subtasks: const [], lists: const [], tags: const [], taskTags: const [], habits: [
        const Habit(id: 1, name: '本地新版', updatedAt: 10),
      ], habitChecks: const [], pomodoros: const []);
      final remote = SyncSnapshot(revision: 1, tasks: const [], subtasks: const [], lists: const [], tags: const [], taskTags: const [], habits: [
        const Habit(id: 1, name: '远端旧版', updatedAt: 5),
        const Habit(id: 2, name: '远端新增', updatedAt: 8),
      ], habitChecks: const [], pomodoros: const []);

      final merged = mergeSnapshots(local, remote);
      expect(merged.habits.length, 2);
      expect(
          merged.habits.firstWhere((h) => h.id == 1).name, '本地新版');
      expect(
          merged.habits.any((h) => h.id == 2 && h.name == '远端新增'), isTrue);
    });
  });
}
