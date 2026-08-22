import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase(this.db);

  final Database db;

  static const _version = 3;

  static Future<AppDatabase> open({String? inMemoryPath}) async {
    final path = inMemoryPath ??
        p.join(await getDatabasesPath(), 'ticktodo.db');
    final db = await openDatabase(
      path,
      version: _version,
      onCreate: (db, _) => createTables(db),
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 1) await createTables(db);
        if (oldV >= 1 && oldV < 2) await migrateV1To2(db);
        if (oldV >= 2 && oldV < 3) await migrateV2To3(db);
      },
    );
    return AppDatabase(db);
  }

  /// v1 → v2：tasks 表新增 repeatRule 列（简化 RRULE 编码，NULL=不重复）。
  static Future<void> migrateV1To2(DatabaseExecutor db) async {
    await db.execute('ALTER TABLE tasks ADD COLUMN repeatRule TEXT');
  }

  /// v2 → v3：
  /// - reminders 表（多提醒时间）
  /// - filters 表（自定义过滤器/智能清单）
  /// - lists.isPinned（清单置顶）
  /// - 数据迁移：已有任务的主提醒 remindAt 写入 reminders
  static Future<void> migrateV2To3(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taskId INTEGER NOT NULL,
        remindAt INTEGER NOT NULL,
        createdAt INTEGER,
        updatedAt INTEGER,
        deletedAt INTEGER
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_reminders_taskId ON reminders(taskId)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS filters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        listIds TEXT NOT NULL DEFAULT '[]',
        tagIds TEXT NOT NULL DEFAULT '[]',
        minPriority INTEGER NOT NULL DEFAULT 0,
        dateMode INTEGER NOT NULL DEFAULT 0,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER,
        updatedAt INTEGER,
        deletedAt INTEGER
      )
    ''');
    final cols =
        await db.query('sqlite_master',
            where: "type='table' AND name='lists'");
    if (cols.isNotEmpty) {
      final listCols = await db.rawQuery('PRAGMA table_info(lists)');
      final hasPinned =
          listCols.any((c) => c['name'] == 'isPinned');
      if (!hasPinned) {
        await db.execute(
            'ALTER TABLE lists ADD COLUMN isPinned INTEGER NOT NULL DEFAULT 0');
      }
    }
    // 已有主提醒迁入 reminders
    final rows = await db.query('tasks',
        columns: ['id', 'remindAt'],
        where: 'remindAt IS NOT NULL AND deletedAt IS NULL');
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final r in rows) {
      await db.insert('reminders', {
        'taskId': r['id'] as int,
        'remindAt': r['remindAt'] as int,
        'createdAt': now,
        'updatedAt': now,
      });
    }
  }

  static Future<void> createTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE lists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color INTEGER NOT NULL DEFAULT 0xFF2F9D45,
        icon INTEGER NOT NULL DEFAULT 0,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        isDefault INTEGER NOT NULL DEFAULT 0,
        isPinned INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER,
        updatedAt INTEGER,
        deletedAt INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color INTEGER NOT NULL DEFAULT 0xFF4C9AFF,
        createdAt INTEGER,
        updatedAt INTEGER,
        deletedAt INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        completed INTEGER NOT NULL DEFAULT 0,
        priority INTEGER NOT NULL DEFAULT 0,
        dueDate TEXT,
        dueTime TEXT,
        remindAt INTEGER,
        listId INTEGER NOT NULL DEFAULT 0,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER,
        updatedAt INTEGER,
        deletedAt INTEGER,
        repeatRule TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE subtasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taskId INTEGER NOT NULL,
        title TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER,
        updatedAt INTEGER,
        deletedAt INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE task_tags (
        taskId INTEGER NOT NULL,
        tagId INTEGER NOT NULL,
        PRIMARY KEY (taskId, tagId)
      )
    ''');
    await db.execute('CREATE INDEX idx_tasks_dueDate ON tasks(dueDate)');
    await db.execute('CREATE INDEX idx_tasks_listId ON tasks(listId)');
    await db.execute('CREATE INDEX idx_subtasks_taskId ON subtasks(taskId)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        taskId INTEGER NOT NULL,
        remindAt INTEGER NOT NULL,
        createdAt INTEGER,
        updatedAt INTEGER,
        deletedAt INTEGER
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_reminders_taskId ON reminders(taskId)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS filters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        listIds TEXT NOT NULL DEFAULT '[]',
        tagIds TEXT NOT NULL DEFAULT '[]',
        minPriority INTEGER NOT NULL DEFAULT 0,
        dateMode INTEGER NOT NULL DEFAULT 0,
        sortOrder INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER,
        updatedAt INTEGER,
        deletedAt INTEGER
      )
    ''');
  }
}
