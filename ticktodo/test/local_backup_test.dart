import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ticktodo/backup/local_backup.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/data/repositories/task_repository.dart';
import 'package:ticktodo/sync/gzip_codec.dart';
import 'package:ticktodo/sync/snapshot.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final Directory root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root.path;
}

void main() {
  late Directory root;
  late AppDatabase appDb;
  late TaskRepository repo;
  late SharedPreferences prefs;
  late LocalBackupManager mgr;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ticktodo_backup_test');
    PathProviderPlatform.instance = _FakePathProvider(root);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    appDb = await AppDatabase.open(inMemoryPath: inMemoryDatabasePath);
    repo = TaskRepository(appDb);
    mgr = LocalBackupManager(
        appDb: appDb, prefs: prefs, overrideDir: root);
  });

  tearDown(() async {
    await appDb.db.close();
    await root.delete(recursive: true);
  });

  test('backupNow 生成 gzip 快照并记录时间', () async {
    await repo.upsertTask(Task(title: '备份任务', listId: 1));

    final path = await mgr.backupNow();
    expect(path, isNotNull);
    expect(p.basename(path!), startsWith('todo_backup_'));
    expect(mgr.lastBackupAt, isNotNull);

    final raw = await File(path).readAsBytes();
    final snap = SyncSnapshot.fromJson(
        jsonDecode(gzipDecode(raw)) as Map<String, dynamic>);
    expect(snap.tasks.single.title, '备份任务');
  });

  test('shouldAutoBackup：从未备份为 true，刚备份后为 false', () async {
    expect(mgr.shouldAutoBackup, isTrue);
    await mgr.backupNow();
    expect(mgr.shouldAutoBackup, isFalse);
  });

  test('autoBackupIfDue：间隔内跳过', () async {
    await mgr.backupNow();
    final ran = await mgr.autoBackupIfDue();
    expect(ran, isFalse);
  });

  test('prune 只保留最近 7 份', () async {
    await mgr.backupNow();
    // 直接写 12 个备份文件模拟多日积累
    final dir = Directory(p.join(root.path, 'backups'));
    await dir.create(recursive: true);
    for (var i = 0; i < 12; i++) {
      final f = File(p.join(dir.path, 'todo_backup_2026010${i % 10}'
          '_00000${i % 10}.json.gz'));
      await f.writeAsBytes([1, 2, 3]);
    }

    await mgr.prune();

    final remain = dir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('todo_backup_'))
        .length;
    expect(
      remain,
      LocalBackupManager.kMaxBackups,
      reason: '应只保留最近 7 份',
    );
  });

  test('listBackups 返回倒序列表', () async {
    await mgr.backupNow();
    // 制造更晚的备份：再写一个时间戳更晚的文件
    final dir = Directory(p.join(root.path, 'backups'));
    await dir.create(recursive: true);
    final later = File(p.join(
        dir.path, 'todo_backup_20270101_000001.json.gz'));
    await later.writeAsBytes([1]);

    // 直接用 backupNow 再备份一份（文件名含新时间戳也可能重名——需保证可区分）
    await Future<void>.delayed(const Duration(seconds: 1));
    await mgr.backupNow();

    final list = await mgr.listBackups();
    expect(list.length, greaterThanOrEqualTo(1));
    for (var i = 0; i + 1 < list.length; i++) {
      expect(
        list[i].modifiedAt.isBefore(list[i + 1].modifiedAt),
        isFalse,
        reason: '应按时间倒序',
      );
    }
    expect(list.first.sizeBytes, greaterThan(0));
    expect(list.first.sizeLabel.isNotEmpty, isTrue);
  });
}