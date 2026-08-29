import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/list_model.dart';
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
  });

  tearDown(() async {
    await appDb.db.close();
  });

  Future<int> addTask(
      {String title = 't', String? dueDate, int priority = 0,
      bool completed = false, int listId = 1}) async {
    final id = await repo.upsertTask(Task(
        title: title, dueDate: dueDate, priority: TaskPriority.fromValue(priority),
        completed: completed, listId: listId));
    return id!;
  }

  test('CRUD + 软删除', () async {
    final id = await addTask(title: '任务A');
    final t = await repo.getTask(id);
    expect(t!.title, '任务A');
    expect(t.completed, false);

    await repo.toggleComplete(id, true);
    expect((await repo.getTask(id))!.completed, true);

    await repo.softDeleteTask(id);
    expect(await repo.getTask(id), isNotNull);
    expect((await repo.getTask(id))!.isDeleted, true);
    expect(await repo.queryAll(), isEmpty);
    expect((await repo.getTask(id))!.deletedAt, isNotNull);
  });

  test('today 视图：今天/过期未完成 出现，未来不出现', () async {
    await addTask(title: '今天到期', dueDate: '2026-08-01');
    await addTask(title: '昨天过期', dueDate: '2026-07-31');
    await addTask(title: '昨天完成', dueDate: '2026-07-31', completed: true);
    await addTask(title: '明天', dueDate: '2026-08-02');
    final rows = await repo.queryToday(today: '2026-08-01');
    final titles = rows.map((t) => t.title).toSet();
    expect(titles, {'今天到期', '昨天过期'});
  });

  test('week 视图边界：今天+6 在内，今天+7 不在', () async {
    await addTask(title: 'D6', dueDate: '2026-08-07');
    await addTask(title: 'D7', dueDate: '2026-08-08');
    await addTask(title: 'D0', dueDate: '2026-08-01');
    final rows = await repo.queryWeek(start: '2026-08-01', end: '2026-08-07');
    final titles = rows.map((t) => t.title).toSet();
    expect(titles, {'D6', 'D0'});
  });

  test('子任务 CRUD', () async {
    final taskId = await addTask();
    final s1 = await repo.upsertSubtask(Subtask(taskId: taskId, title: '子1'));
    final s2 = await repo.upsertSubtask(
        Subtask(taskId: taskId, title: '子2', sortOrder: 2));
    expect((await repo.subtasksOf(taskId)).length, 2);

    await repo.toggleSubtask(s1!, true);
    expect((await repo.subtasksOf(taskId)).firstWhere((s) => s.id == s1).completed, true);

    await repo.softDeleteSubtask(s2!);
    expect((await repo.subtasksOf(taskId)).length, 1);
  });

  test('清单/标签 CRUD', () async {
    final listId = await meta.ensureDefaultList();
    expect(listId, greaterThan(0));
    expect((await meta.getList(listId))!.name, '收集箱');

    final id = await meta.upsertList(ListModel(name: '工作'));
    expect((await meta.queryLists()).length, 2);
    await meta.softDeleteList(id!);
    expect((await meta.queryLists()).length, 1);

    final tagId = await meta.upsertTag(Tag(name: '重要'));
    final taskId = await addTask();
    await meta.setTaskTags(taskId, [tagId!]);
    expect(await meta.tagIdsOfTask(taskId), [tagId]);
  });

  test('标签过滤查询', () async {
    final tagA = (await meta.upsertTag(Tag(name: 'A')))!;
    final tagB = (await meta.upsertTag(Tag(name: 'B')))!;
    final t1 = await addTask(title: '带A');
    await addTask(title: '不带');
    await meta.linkTaskTag(t1, tagA);
    await meta.linkTaskTag(t1, tagB);
    expect((await repo.queryByTags([tagA])).length, 1);
    expect((await repo.queryByTags([tagB])).length, 1);
  });

  test('取消标签为软删墓碑：查询不再命中，重新添加恢复并清墓碑', () async {
    final tagA = (await meta.upsertTag(Tag(name: 'A')))!;
    final t1 = await addTask(title: '带A');
    await meta.linkTaskTag(t1, tagA);
    expect((await repo.queryByTags([tagA])).length, 1);

    await meta.unlinkTaskTag(t1, tagA);
    expect(await repo.queryByTags([tagA]), isEmpty);
    expect(await meta.tagIdsOfTask(t1), isEmpty);
    // 墓碑行留在库里，取消事件要靠它同步到其他设备
    final tombstone = await appDb.db.query('task_tags',
        where: 'taskId = ? AND tagId = ?', whereArgs: [t1, tagA]);
    expect(tombstone.single['deletedAt'], isNotNull);

    await meta.linkTaskTag(t1, tagA);
    expect((await repo.queryByTags([tagA])).length, 1);
    final relinked = await appDb.db.query('task_tags',
        where: 'taskId = ? AND tagId = ?', whereArgs: [t1, tagA]);
    expect(relinked.single['deletedAt'], isNull);
    expect(relinked.single['updatedAt'], isNotNull);
  });

  test('本地无关联行时取消标签 → 写入纯墓碑', () async {
    final tagA = (await meta.upsertTag(Tag(name: 'A')))!;
    final t1 = await addTask(title: '无关联');
    await meta.unlinkTaskTag(t1, tagA);
    final rows = await appDb.db.query('task_tags',
        where: 'taskId = ? AND tagId = ?', whereArgs: [t1, tagA]);
    expect(rows.single['deletedAt'], isNotNull);
    expect(await repo.queryByTags([tagA]), isEmpty);
  });

  test('删除标签时其关联一并软删留墓碑', () async {
    final tagA = (await meta.upsertTag(Tag(name: 'A')))!;
    final t1 = await addTask(title: '带A');
    await meta.linkTaskTag(t1, tagA);
    await meta.softDeleteTag(tagA);
    expect(await repo.queryByTags([tagA]), isEmpty);
    final links =
        await appDb.db.query('task_tags', where: 'tagId = ?', whereArgs: [tagA]);
    expect(links.single['deletedAt'], isNotNull);
  });

  test('purgeDeleted 清理过期标签墓碑，保留期内的不动', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    const day = 24 * 3600 * 1000;
    final t1 = await addTask(title: 't');
    await appDb.db.insert('task_tags',
        {'taskId': t1, 'tagId': 99, 'updatedAt': now - 91 * day, 'deletedAt': now - 91 * day});
    await appDb.db.insert('task_tags',
        {'taskId': t1, 'tagId': 98, 'updatedAt': now, 'deletedAt': now});
    await repo.purgeDeleted(olderThanMs: 90 * day);

    final rows = await appDb.db.query('task_tags');
    expect(rows.where((r) => r['tagId'] == 99), isEmpty);
    expect(rows.where((r) => r['tagId'] == 98), isNotEmpty);
  });

  test('default list 不可重复创建', () async {
    final a = await meta.ensureDefaultList();
    final b = await meta.ensureDefaultList();
    expect(a, b);
  });

  test('lastMutationAt 随写入更新', () async {
    final before = repo.lastMutationAt;
    await addTask();
    expect(repo.lastMutationAt, greaterThanOrEqualTo(before));
  });
}
