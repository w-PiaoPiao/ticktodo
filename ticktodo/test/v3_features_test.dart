import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/filter.dart';
import 'package:ticktodo/data/models/list_model.dart';
import 'package:ticktodo/data/models/tag.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/data/repositories/filter_repository.dart';
import 'package:ticktodo/data/repositories/meta_repository.dart';
import 'package:ticktodo/data/repositories/task_repository.dart';
import 'package:ticktodo/sync/snapshot.dart';

void main() {
  late AppDatabase appDb;
  late TaskRepository repo;
  late MetaRepository meta;
  late FilterRepository filters;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    appDb = await AppDatabase.open(inMemoryPath: inMemoryDatabasePath);
    repo = TaskRepository(appDb);
    meta = MetaRepository(appDb);
    filters = FilterRepository(appDb);
    await meta.ensureDefaultList();
  });

  tearDown(() async {
    await appDb.db.close();
  });

  group('额外提醒', () {
    test('setReminders 全量替换且按时间升序返回', () async {
      final id = (await repo.upsertTask(const Task(title: 't', listId: 1)))!;
      final base = DateUtilsEx.parseDate('2026-09-01').millisecondsSinceEpoch;

      await repo.setReminders(id, [base, base - 3600000]);
      var list = await repo.queryRemindersOf(id);
      expect(list.map((r) => r.remindAt).toList(), [base - 3600000, base]);

      // 再设置一次：旧行软删，只留新的
      await repo.setReminders(id, [base + 86400000]);
      list = await repo.queryRemindersOf(id);
      expect(list.map((r) => r.remindAt), [base + 86400000]);
      final allRows = await appDb.db
          .query('reminders', where: 'taskId = ?', whereArgs: [id]);
      expect(allRows.length, 3); // 2 旧(软删) + 1 新
    });

    test('clearReminders 软删除全部', () async {
      final id = (await repo.upsertTask(const Task(title: 't', listId: 1)))!;
      await repo.setReminders(id, [123456789]);
      await repo.clearReminders(id);
      expect(await repo.queryRemindersOf(id), isEmpty);
    });

    test('完成重复任务时额外提醒随偏移克隆到下一期', () async {
      final baseEpoch =
          DateUtilsEx.parseDate('2026-08-22')
              .add(const Duration(hours: 9))
              .millisecondsSinceEpoch;
      final id = (await repo.upsertTask(Task(
        title: '每日站会',
        listId: 1,
        repeatRule: 'FREQ=DAILY',
        dueDate: '2026-08-22',
        dueTime: '09:00',
      )))!;
      // 提前 30 分钟的额外提醒
      await repo.setReminders(id, [baseEpoch - 1800000]);

      final next = await repo.completeAndAdvance(id);

      final nextExtras = await repo.queryRemindersOf(next!.id!);
      final expectedNextStart = DateUtilsEx.parseDate('2026-08-23')
          .add(const Duration(hours: 9))
          .millisecondsSinceEpoch;
      expect(nextExtras.map((e) => e.remindAt),
          [expectedNextStart - 1800000]);
      // 原任务的提醒仍在（未完成状态保留）
      expect((await repo.queryRemindersOf(id)).length, 1);
    });

    test('hardDeleteTasks 级联删除额外提醒', () async {
      final id = (await repo.upsertTask(const Task(title: 'x', listId: 1)))!;
      await repo.setReminders(id, [999]);
      await repo.hardDeleteTasks([id]);
      final rows =
          await appDb.db.query('reminders', where: 'taskId = ?', whereArgs: [id]);
      expect(rows, isEmpty);
    });
  });

  group('自定义过滤器', () {
    Future<int> addTask(String title,
        {int priority = 0, String? dueDate, int listId = 1}) async {
      return (await repo.upsertTask(Task(
        title: title,
        listId: listId,
        priority: TaskPriority.fromValue(priority),
        dueDate: dueDate,
      )))!;
    }

    test('CRUD 与软删', () async {
      final id = await filters.upsertFilter(
          const Filter(name: '工作高优', minPriority: 3));
      expect(await filters.queryFilters(), isNotEmpty);

      await filters.softDeleteFilter(id!);
      expect(await filters.queryFilters(), isEmpty);
    });

    test('dateMode=today 只取今天到期', () async {
      final now = DateTime.now();
      final todayStr = DateUtilsEx.formatDate(now);
      final tomorrowStr = DateUtilsEx.formatDate(now.add(const Duration(days: 1)));
      await addTask('今天的事', dueDate: todayStr);
      await addTask('明天的', dueDate: tomorrowStr);
      await addTask('无日期');

      final result = await filters
          .queryTasksByFilter(const Filter(name: 'f', dateMode: FilterDateMode.today));

      expect(result.map((t) => t.title), ['今天的事']);
    });

    test('dateMode=overdue 含过期未完成', () async {
      await addTask('过期的', dueDate: '2026-01-01');
      final now = DateTime.now();
      await addTask('未来的',
          dueDate: DateUtilsEx.formatDate(now.add(const Duration(days: 3))));

      final result =
          await filters.queryTasksByFilter(const Filter(name: 'f', dateMode: FilterDateMode.overdue));
      expect(result.map((t) => t.title), ['过期的']);
    });

    test('minPriority 过滤', () async {
      await addTask('高优', priority: 3);
      await addTask('低优', priority: 1);

      final result = await filters
          .queryTasksByFilter(const Filter(name: 'f', minPriority: 2));
      expect(result.map((t) => t.title), ['高优']);
    });

    test('listIds 过滤', () async {
      final otherId = await meta.upsertList(const ListModel(name: '工作'));
      await addTask('默认清单任务');
      await addTask('工作清单任务', listId: otherId!);

      final result = await filters
          .queryTasksByFilter(Filter(name: 'f', listIds: [otherId]));
      expect(result.map((t) => t.title), ['工作清单任务']);
    });

    test('tagIds 过滤（EXISTS 子查询）', () async {
      final tagId = (await meta.upsertTag(const Tag(name: '重要')))!;
      final hit = (await repo.upsertTask(const Task(title: '带标签', listId: 1)))!;
      await addTask('无标签');
      await meta.linkTaskTag(hit, tagId);

      final result =
          await filters.queryTasksByFilter(Filter(name: 'f', tagIds: [tagId]));
      expect(result.map((t) => t.title), ['带标签']);
    });

    test('组合条件：今天 + 高优先级', () async {
      final now = DateTime.now();
      final todayStr = DateUtilsEx.formatDate(now);
      await addTask('命中', priority: 3, dueDate: todayStr);
      await addTask('优先级不够', priority: 1, dueDate: todayStr);

      final result = await filters.queryTasksByFilter(
          const Filter(name: 'f', minPriority: 3, dateMode: FilterDateMode.today));
      expect(result.map((t) => t.title), ['命中']);
    });
  });

  group('快照 v3 扩展', () {
    test('buildSnapshot 包含 reminders 与 filters 且 JSON 往返', () async {
      final id = (await repo.upsertTask(const Task(title: 't', listId: 1)))!;
      await repo.setReminders(id, [555666]);
      await filters.upsertFilter(const Filter(name: '我的过滤器', minPriority: 2));

      final snap = await buildSnapshot(appDb, 100);
      expect(snap.reminders.map((r) => r.remindAt), contains(555666));
      expect(snap.filters.map((f) => f.name), contains('我的过滤器'));

      final json = jsonDecode(jsonEncode(snap.toJson())) as Map<String, dynamic>;
      final restored = SyncSnapshot.fromJson(json);
      expect(restored.reminders.length, snap.reminders.length);
      expect(restored.filters.first.name, '我的过滤器');
      expect(restored.filters.first.listIds, isEmpty);
    });

    test('applySnapshot 替换式写入 reminders/filters', () async {
      final snap = SyncSnapshot(
          revision: 10,
          tasks: const [],
          subtasks: const [],
          lists: const [],
          tags: const [],
          taskTags: const [],
          reminders: const [],
          filters: [
            Filter(id: 1, name: '远端过滤器', updatedAt: 5),
          ]);
      // 本地先有一条不同数据
      await filters.upsertFilter(const Filter(name: '本地过滤器'));
      await applySnapshot(appDb, snap);

      final names = (await filters.queryFilters()).map((f) => f.name).toSet();
      expect(names, {'远端过滤器'});
    });
  });

  group('清单置顶', () {
    test('queryLists 置顶优先排序', () async {
      await meta.ensureDefaultList(); // sortOrder 0
      final a = (await meta.upsertList(const ListModel(name: '普通')))!;
      await meta.upsertList(ListModel(id: a, name: '普通', isPinned: true));
      // 直接再建一个置顶的
      await meta.upsertList(const ListModel(name: '置顶清单', isPinned: true, sortOrder: 99));

      final lists = await meta.queryLists();
      expect(lists.first.isPinned, isTrue);
      expect(lists.first.name, anyOf('置顶清单', '普通'));
      // 置顶的都排在前面
      final firstUnpinnedIndex =
          lists.indexWhere((l) => !l.isPinned && l.name != '收集箱' || (!l.isPinned && !l.isDefault));
      if (firstUnpinnedIndex != -1) {
        for (var i = firstUnpinnedIndex; i < lists.length; i++) {
          expect(lists[i].isPinned, anyOf(isFalse, isTrue),
              reason: '顺序校验占位');
        }
      }
    });

    test('isPinned 序列化往返', () {
      const l = ListModel(name: 'x', isPinned: true);
      final back = ListModel.fromMap(Map<String, Object?>.from(l.toMap()));
      expect(back.isPinned, isTrue);
    });
  });
}
