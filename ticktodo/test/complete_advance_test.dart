import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/subtask.dart';
import 'package:ticktodo/data/models/tag.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/data/repositories/meta_repository.dart';
import 'package:ticktodo/data/repositories/task_repository.dart';

void main() {
  late AppDatabase appDb;
  late TaskRepository repo;
  late MetaRepository meta;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    appDb = await AppDatabase.open(inMemoryPath: inMemoryDatabasePath);
    repo = TaskRepository(appDb);
    meta = MetaRepository(appDb);
    await meta.ensureDefaultList(); // listId=1 收集箱
  });

  tearDown(() async {
    await appDb.db.close();
  });

  Future<int> seedTask({
    String title = '每日站会',
    String? repeatRule,
    String? dueDate,
    String? dueTime,
    int? remindAt,
  }) async {
    return (await repo.upsertTask(Task(
      title: title,
      listId: 1,
      repeatRule: repeatRule,
      dueDate: dueDate,
      dueTime: dueTime,
      remindAt: remindAt,
    )))!;
  }

  group('completeAndAdvance', () {
    test('完成每天重复任务生成下一期未完成实例', () async {
      final id = await seedTask(repeatRule: 'FREQ=DAILY', dueDate: '2026-08-22');

      final next = await repo.completeAndAdvance(id);

      final original = await repo.getTask(id);
      expect(original!.completed, isTrue);

      expect(next, isNotNull);
      expect(next!.id, isNot(id));
      expect(next.completed, isFalse);
      expect(next.dueDate, '2026-08-23');
      expect(next.title, '每日站会');
      expect(next.listId, 1);
    });

    test('下一期克隆子任务并重置完成状态', () async {
      final id = await seedTask(repeatRule: 'FREQ=DAILY', dueDate: '2026-08-22');
      await repo.upsertSubtask(Subtask(taskId: id, title: '准备幻灯片'));
      await repo.upsertSubtask(Subtask(taskId: id, title: '发言', completed: true));

      final next = await repo.completeAndAdvance(id);

      final subs = await repo.subtasksOf(next!.id!);
      expect(subs.map((s) => s.title).toSet(), {'准备幻灯片', '发言'});
      expect(subs.every((s) => !s.completed), isTrue);
    });

    test('下一期克隆标签关联', () async {
      final id = await seedTask(repeatRule: 'FREQ=DAILY', dueDate: '2026-08-22');
      final tagId = (await meta.upsertTag(const Tag(name: '工作')))!;
      await meta.linkTaskTag(id, tagId);

      final next = await repo.completeAndAdvance(id);

      final tagIds = await meta.tagIdsOfTask(next!.id!);
      expect(tagIds, contains(tagId));
    });

    test('提醒保持相对偏移（提前 30 分钟）', () async {
      final baseEpoch = DateUtilsEx.parseDate('2026-08-22')
          .add(const Duration(hours: 9))
          .millisecondsSinceEpoch; // 到期 09:00
      final remindAt = DateUtilsEx.parseDate('2026-08-22')
          .add(const Duration(hours: 8, minutes: 30))
          .millisecondsSinceEpoch; // 提醒 08:30
      final id = await seedTask(
          repeatRule: 'FREQ=DAILY',
          dueDate: '2026-08-22',
          dueTime: '09:00',
          remindAt: remindAt);

      final next = await repo.completeAndAdvance(id);

      final expectedNextStart = DateUtilsEx.parseDate('2026-08-23')
          .add(const Duration(hours: 9))
          .millisecondsSinceEpoch;
      expect(next!.remindAt, expectedNextStart + (remindAt - baseEpoch));
    });

    test('全天重复任务（无 dueTime）完成 → 提醒保留并推进到下一期', () async {
      // 旧实现：无 dueTime 时下一期 remindAt 为 null，提醒整段丢失
      final remindAt = DateUtilsEx.parseDate('2026-08-22')
          .add(const Duration(hours: 9))
          .millisecondsSinceEpoch;
      final id = await seedTask(
          repeatRule: 'FREQ=DAILY',
          dueDate: '2026-08-22',
          remindAt: remindAt);

      final next = await repo.completeAndAdvance(id);

      expect(
          next!.remindAt,
          DateUtilsEx.parseDate('2026-08-23')
              .add(const Duration(hours: 9))
              .millisecondsSinceEpoch);
    });

    test('dueTime 脏数据不中断完成操作', () async {
      final id = await seedTask(
          repeatRule: 'FREQ=DAILY',
          dueDate: '2026-08-22',
          dueTime: '垃圾');

      final next = await repo.completeAndAdvance(id);

      expect(next!.dueDate, '2026-08-23');
    });

    test('无重复规则任务仅完成，返回 null', () async {
      final id = await seedTask(dueDate: '2026-08-22');

      final next = await repo.completeAndAdvance(id);

      expect(next, isNull);
      expect((await repo.getTask(id))!.completed, isTrue);
      final all = await repo.queryAll(includeCompleted: false);
      expect(all, isEmpty);
    });

    test('已完成任务再次调用返回 null 且不生成新一期', () async {
      final id = await seedTask(repeatRule: 'FREQ=DAILY', dueDate: '2026-08-22');
      await repo.toggleComplete(id, true);

      final next = await repo.completeAndAdvance(id);

      expect(next, isNull);
      final all = await repo.queryAll();
      expect(all.length, 1);
    });

    test('有规则但无到期日：仅完成返回 null', () async {
      final id = await seedTask(repeatRule: 'FREQ=DAILY');

      final next = await repo.completeAndAdvance(id);

      expect(next, isNull);
      expect((await repo.getTask(id))!.completed, isTrue);
    });
  });

  group('searchTasks', () {
    test('标题关键词命中且排除已删除', () async {
      final hit = await repo.upsertTask(const Task(title: '写周报', listId: 1));
      await repo.upsertTask(const Task(title: '买菜', listId: 1));
      final deleted =
          await repo.upsertTask(const Task(title: '周报模板', listId: 1));
      await repo.softDeleteTask(deleted!);

      final result = await repo.searchTasks('周报');

      expect(result.map((t) => t.id), [hit]);
    });

    test('备注命中与大小写不敏感', () async {
      final byNote =
          await repo.upsertTask(const Task(title: '整理房间', note: '记得买 ABC 清洁剂', listId: 1));
      final byCase = await repo.upsertTask(const Task(title: 'Review PR abc123', listId: 1));

      expect((await repo.searchTasks('清洁剂')).map((t) => t.id), [byNote]);
      expect((await repo.searchTasks('ABC')).map((t) => t.id).toSet(),
          {byNote, byCase});
    });

    test('空关键词返回空列表', () async {
      await repo.upsertTask(const Task(title: '任意', listId: 1));
      expect(await repo.searchTasks(''), isEmpty);
      expect(await repo.searchTasks('   '), isEmpty);
    });
  });

  group('批量操作', () {
    test('bulkSoftDelete 批量软删除', () async {
      final a = (await repo.upsertTask(const Task(title: 'a', listId: 1)))!;
      final b = (await repo.upsertTask(const Task(title: 'b', listId: 1)))!;
      await repo.upsertTask(const Task(title: 'c', listId: 1));

      await repo.bulkSoftDelete([a, b]);

      final alive = await repo.queryAll();
      expect(alive.map((t) => t.title), ['c']);
    });

    test('bulkMoveToList 批量移动清单', () async {
      final a = (await repo.upsertTask(const Task(title: 'a', listId: 1)))!;
      final b = (await repo.upsertTask(const Task(title: 'b', listId: 1)))!;

      await repo.bulkMoveToList([a, b], 9);

      final tasks = await repo.queryAll();
      expect(tasks.every((t) => t.listId == 9), isTrue);
    });

    test('bulkSetDueDate 设置与清除日期', () async {
      final a = (await repo.upsertTask(const Task(title: 'a', listId: 1)))!;
      final b = (await repo.upsertTask(const Task(title: 'b', listId: 1)))!;

      await repo.bulkSetDueDate([a, b], '2026-09-01');
      var tasks = await repo.queryAll();
      expect(tasks.every((t) => t.dueDate == '2026-09-01'), isTrue);

      await repo.bulkSetDueDate([a, b], null);
      tasks = await repo.queryAll();
      expect(tasks.every((t) => t.dueDate == null), isTrue);
    });

    test('空 id 列表不报错', () async {
      await repo.bulkSoftDelete([]);
      await repo.bulkMoveToList([], 1);
      await repo.bulkSetDueDate([], null);
    });
  });

  group('回收站', () {
    test('queryDeleted 按删除时间倒序返回', () async {
      final a = (await repo.upsertTask(const Task(title: 'a', listId: 1)))!;
      final b = (await repo.upsertTask(const Task(title: 'b', listId: 1)))!;
      await repo.softDeleteTask(a);
      await Future.delayed(const Duration(milliseconds: 5));
      await repo.softDeleteTask(b);

      final deleted = await repo.queryDeleted();

      expect(deleted.map((t) => t.title).toList(), ['b', 'a']);
    });

    test('hardDeleteTasks 级联删除子任务与标签关联', () async {
      final id = (await repo.upsertTask(const Task(title: 'x', listId: 1)))!;
      await repo.upsertSubtask(Subtask(taskId: id, title: '子任务'));
      final tagId = (await meta.upsertTag(const Tag(name: '标签')))!;
      await meta.linkTaskTag(id, tagId);

      await repo.hardDeleteTasks([id]);

      expect(await repo.getTask(id), isNull);
      expect(await repo.subtasksOf(id), isEmpty);
      expect(await meta.tagIdsOfTask(id), isEmpty);
      final rows = await appDb.db.query('tags');
      expect(rows.length, 1); // 标签本身仍在
    });

    test('purgeDeleted 只清理超龄记录', () async {
      final fresh = (await repo.upsertTask(const Task(title: 'fresh', listId: 1)))!;
      final old = (await repo.upsertTask(const Task(title: 'old', listId: 1)))!;
      await repo.softDeleteTask(fresh);
      // 手工把 old 的删除时间改到 40 天前
      final stale = DateTime.now()
          .subtract(const Duration(days: 40))
          .millisecondsSinceEpoch;
      await appDb.db.update('tasks', {'deletedAt': stale},
          where: 'id = ?', whereArgs: [old]);

      final purged = await repo.purgeDeleted(olderThanMs: 30 * 24 * 3600 * 1000);

      expect(purged, 1);
      expect(await repo.getTask(old), isNull);
      expect((await repo.queryDeleted()).map((t) => t.id), [fresh]);
    });
  });
}
