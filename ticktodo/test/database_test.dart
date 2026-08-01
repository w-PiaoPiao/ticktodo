import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ticktodo/data/db/app_database.dart';

void main() {
  late AppDatabase appDb;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    appDb = await AppDatabase.open(inMemoryPath: inMemoryDatabasePath);
  });

  tearDown(() async {
    await appDb.db.close();
  });

  test('建表成功，插入/查询往返', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await appDb.db.insert('tasks', {
      'title': '测试任务',
      'note': '备注',
      'completed': 0,
      'priority': 2,
      'dueDate': '2026-08-02',
      'listId': 1,
      'createdAt': now,
      'updatedAt': now,
    });
    final rows = await appDb.db.query('tasks');
    expect(rows.length, 1);
    expect(rows.first['title'], '测试任务');
    expect(rows.first['dueDate'], '2026-08-02');
    expect(rows.first['deletedAt'], isNull);
  });

  test('软删除字段存在且可写', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await appDb.db.insert('lists', {
      'name': '收集箱',
      'isDefault': 1,
      'createdAt': now,
      'updatedAt': now,
    });
    await appDb.db.update('lists', {'deletedAt': now}, where: 'id = ?', whereArgs: [id]);
    final rows = await appDb.db.query('lists', where: 'id = ?', whereArgs: [id]);
    expect(rows.first['deletedAt'], now);
  });

  test('索引存在（创建不报错）', () async {
    await appDb.db.insert('tasks', {
      'title': 'x',
      'listId': 1,
    });
    final rows = await appDb.db
        .rawQuery("SELECT name FROM sqlite_master WHERE type='index'");
    final names = rows.map((r) => r['name']).toSet();
    expect(names, contains('idx_tasks_dueDate'));
    expect(names, contains('idx_subtasks_taskId'));
  });
}
