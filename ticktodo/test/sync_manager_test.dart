import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/data/repositories/task_repository.dart';
import 'package:ticktodo/sync/gzip_codec.dart';
import 'package:ticktodo/sync/snapshot.dart';
import 'package:ticktodo/sync/sync_manager.dart';
import 'package:ticktodo/sync/sync_settings.dart';
import 'package:ticktodo/sync/webdav_client.dart';

import 'support/in_memory_credential_store.dart';

void main() {
  late AppDatabase appDb;
  late TaskRepository repo;
  late SyncSettings settings;
  late List<http.Request> requests;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = InMemoryCredentialStore();
    await store.write('webdav_url', 'https://dav.jianguoyun.com/dav/');
    await store.write('webdav_user', 'u@example.com');
    await store.write('webdav_pass', 'apppass');
    settings = SyncSettings(prefs, store);
    await settings.load();
    appDb = await AppDatabase.open(inMemoryPath: inMemoryDatabasePath);
    repo = TaskRepository(appDb);
    requests = [];
  });

  tearDown(() async {
    await appDb.db.close();
  });

  MockClient noBackupServer() {
    return MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') return http.Response('', 404);
      return http.Response('ok', 201);
    });
  }

  SyncManager managerWith(MockClient mock) {
    return SyncManager(
      appDb: appDb,
      taskRepository: repo,
      settings: settings,
      client: WebDavClient(
        settings.webdavUrl!,
        settings.username!,
        settings.password!,
        client: mock,
      ),
    );
  }

  test('首次同步：远端空 → 上传本地', () async {
    await repo.upsertTask(Task(title: '任务1', listId: 1));
    final m = managerWith(noBackupServer());
    final result = await m.syncNow();
    expect(result.success, true);
    expect(result.didUpload, true);
    expect(requests.any((r) => r.method == 'PUT'), true);

    final put = requests.firstWhere((r) => r.method == 'PUT');
    final snap = SyncSnapshot.fromJson(
        jsonDecode(gzipDecode(put.bodyBytes)) as Map<String, dynamic>);
    expect(snap.tasks.single.title, '任务1');
  });

  test('远端新 → 下载应用', () async {
    final remoteSnap = SyncSnapshot(
      revision: DateTime.now().millisecondsSinceEpoch,
      tasks: [
        Task(id: 1, title: '远端任务', listId: 1,
            updatedAt: DateTime.now().millisecondsSinceEpoch),
      ],
      subtasks: const [],
      lists: const [],
      tags: const [],
      taskTags: const [],
    );
    final mock = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return http.Response.bytes(
            Uint8List.fromList(gzipEncode(remoteSnap.encode())), 200);
      }
      return http.Response('ok', 201);
    });
    final m = managerWith(mock);
    final result = await m.syncNow();
    expect(result.didDownload, true);
    expect((await repo.queryAll()).single.title, '远端任务');
  });

  test('本地新（远超过窗口）→ 上传本地', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await repo.upsertTask(Task(title: '本地任务', listId: 1));
    final remoteSnap = SyncSnapshot(
      revision: now - Duration(hours: 2).inMilliseconds,
      tasks: [
        Task(id: 1, title: '旧远端', listId: 1, updatedAt: now - 2 * 3600000),
      ],
      subtasks: const [],
      lists: const [],
      tags: const [],
      taskTags: const [],
    );
    final mock = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return http.Response.bytes(
            Uint8List.fromList(gzipEncode(remoteSnap.encode())), 200);
      }
      return http.Response('ok', 201);
    });
    final m = managerWith(mock);
    final result = await m.syncNow();
    expect(result.didUpload, true);
    expect((await repo.queryAll()).single.title, '本地任务');
  });

  test('凭据持久化（setCredentials 写入安全存储并更新内存缓存）', () async {
    await settings.setCredentials('https://dav.jianguoyun.com/dav/', 'new@u', 'newpass');
    expect(settings.webdavUrl, 'https://dav.jianguoyun.com/dav/');
    expect(settings.username, 'new@u');
    expect(settings.password, 'newpass');
    expect(settings.lastSyncAt, isNull);
  });

  test('无凭据 → 跳过同步', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final emptySettings = SyncSettings(prefs, InMemoryCredentialStore());
    await emptySettings.load();
    final m = SyncManager(
        appDb: appDb, taskRepository: repo, settings: emptySettings);
    final result = await m.syncNow();
    expect(result.success, true);
    expect(result.didUpload, false);
    expect(requests, isEmpty);
  });

  test('migrateLegacyPrefs：旧明文凭据迁入安全存储并清除 prefs', () async {
    SharedPreferences.setMockInitialValues({
      'webdav_url': 'https://legacy.example.com/dav/',
      'webdav_user': 'legacy@u',
      'webdav_pass': 'legacypass',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = InMemoryCredentialStore();
    final s = SyncSettings(prefs, store);
    await s.migrateLegacyPrefs();

    expect(await store.read('webdav_url'), 'https://legacy.example.com/dav/');
    expect(await store.read('webdav_user'), 'legacy@u');
    expect(await store.read('webdav_pass'), 'legacypass');
    expect(s.webdavUrl, 'https://legacy.example.com/dav/');
    expect(s.hasCredentials, isTrue);
    expect(prefs.getString('webdav_url'), isNull);
    expect(prefs.getString('webdav_pass'), isNull);
  });

  test('migrateLegacyPrefs：安全存储已有凭据时以安全存储为准', () async {
    SharedPreferences.setMockInitialValues({
      'webdav_url': 'https://old.example.com/dav/',
      'webdav_user': 'old@u',
      'webdav_pass': 'oldpass',
    });
    final prefs = await SharedPreferences.getInstance();
    final store = InMemoryCredentialStore();
    await store.write('webdav_url', 'https://secure.example.com/dav/');
    await store.write('webdav_user', 'secure@u');
    await store.write('webdav_pass', 'securepass');
    final s = SyncSettings(prefs, store);
    await s.load();
    await s.migrateLegacyPrefs();

    expect(s.webdavUrl, 'https://secure.example.com/dav/');
    expect(prefs.getString('webdav_url'), isNull);
  });

  test('refreshClient：换绑后 client 使用新凭据', () async {
    final m = managerWith(noBackupServer());
    expect(m.client!.username, 'u@example.com');

    await settings.setCredentials(
        'https://dav.jianguoyun.com/dav/', 'swapped@u', 'newpass');
    m.refreshClient();

    expect(m.client, isNotNull);
    expect(m.client!.username, 'swapped@u');
    expect(m.client!.password, 'newpass');
  });
}
