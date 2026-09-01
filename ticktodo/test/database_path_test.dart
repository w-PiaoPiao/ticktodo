import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ticktodo/core/logger.dart';
import 'package:ticktodo/data/db/app_database.dart';

/// 测试用 path_provider 桩：Application Support 指向临时目录。
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final Directory root;

  @override
  Future<String?> getApplicationSupportPath() async => root.path;
}

/// 在指定路径建一个 v5 库并写入一条带 marker 的任务。
Future<Database> createLegacyDbAt(String path, String marker) async {
  final dir = Directory(p.dirname(path));
  await dir.create(recursive: true);
  final db = await openDatabase(
    path,
    version: 5,
    onCreate: (d, _) => AppDatabase.createTables(d),
  );
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.insert('tasks', {
    'title': marker,
    'note': '',
    'completed': 0,
    'priority': 0,
    'listId': 1,
    'createdAt': now,
    'updatedAt': now,
  });
  return db;
}

Future<String?> firstTaskTitle(Database db) async {
  final rows = await db.query('tasks', columns: ['title']);
  return rows.isEmpty ? null : rows.first['title'] as String?;
}

void main() {
  late Directory supportRoot;
  final originalCwd = Directory.current;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppLogger.enabled = false; // 本组测试不写日志文件
  });

  tearDownAll(() {
    AppLogger.enabled = true;
  });

  setUp(() async {
    supportRoot = await Directory.systemTemp.createTemp('ticktodo_db_path');
    PathProviderPlatform.instance = _FakePathProvider(supportRoot);
  });

  tearDown(() async {
    Directory.current = originalCwd;
    try {
      await supportRoot.delete(recursive: true);
    } catch (_) {
      // 个别平台偶尔忙，忽略
    }
  });

  test('桌面端 resolveDatabasePath 为 Application Support 下绝对路径', () async {
    final path = await AppDatabase.resolveDatabasePath();
    expect(p.isAbsolute(path), isTrue);
    expect(path, p.join(supportRoot.path, 'databases', 'ticktodo.db'));
  });

  test('resolveDatabasePath 不随 cwd 变化（黑屏根因回归）', () async {
    final before = await AppDatabase.resolveDatabasePath();
    final altCwd = await Directory.systemTemp.createTemp('ticktodo_cwd');
    try {
      Directory.current = altCwd;
      final after = await AppDatabase.resolveDatabasePath();
      expect(after, before);
    } finally {
      Directory.current = originalCwd;
      await altCwd.delete(recursive: true);
    }
  });

  test('新位置无库且 cwd 兜底存在旧库时自动迁移（数据可读、源保留）', () async {
    final legacyCwd = await Directory.systemTemp.createTemp('ticktodo_legacy');
    final legacyPath = p.join(legacyCwd.path, '.dart_tool',
        'sqflite_common_ffi', 'databases', 'ticktodo.db');
    final legacyDb = await createLegacyDbAt(legacyPath, '迁移前任务');
    await legacyDb.close();

    try {
      Directory.current = legacyCwd;
      final appDb = await AppDatabase.open();
      addTearDown(() => appDb.db.close());

      expect(await firstTaskTitle(appDb.db), '迁移前任务');
      final target = await AppDatabase.resolveDatabasePath();
      expect(await File(target).exists(), isTrue);
      // 复制而非移动：源文件保留
      expect(await File(legacyPath).exists(), isTrue);
    } finally {
      Directory.current = originalCwd;
      await legacyCwd.delete(recursive: true);
    }
  });

  test('新位置已有库时不被旧副本覆盖', () async {
    final target = await AppDatabase.resolveDatabasePath();
    final targetDb = await createLegacyDbAt(target, '新库数据');
    await targetDb.close();

    final legacyCwd = await Directory.systemTemp.createTemp('ticktodo_legacy2');
    try {
      final legacyPath = p.join(legacyCwd.path, '.dart_tool',
          'sqflite_common_ffi', 'databases', 'ticktodo.db');
      final legacyDb = await createLegacyDbAt(legacyPath, '旧库数据');
      await legacyDb.close();

      Directory.current = legacyCwd;
      final appDb = await AppDatabase.open();
      addTearDown(() => appDb.db.close());
      expect(await firstTaskTitle(appDb.db), '新库数据');
    } finally {
      Directory.current = originalCwd;
      await legacyCwd.delete(recursive: true);
    }
  });
}
