import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase(this.db);

  final Database db;

  static const _version = 1;

  static Future<AppDatabase> open({String? inMemoryPath}) async {
    final path = inMemoryPath ??
        p.join(await getDatabasesPath(), 'ticktodo.db');
    final db = await openDatabase(
      path,
      version: _version,
      onCreate: (db, _) => createTables(db),
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 1) await createTables(db);
      },
    );
    return AppDatabase(db);
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
        deletedAt INTEGER
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
  }
}
