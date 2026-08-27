import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ticktodo/app.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/list_model.dart';
import 'package:ticktodo/data/repositories/meta_repository.dart';
import 'package:ticktodo/data/repositories/task_repository.dart';
import 'package:ticktodo/notifications/notification_service.dart';
import 'package:ticktodo/sync/sync_manager.dart';
import 'package:ticktodo/sync/sync_settings.dart';
import 'support/in_memory_credential_store.dart';

class MockTaskRepo extends Mock implements TaskRepository {}
class MockMetaRepo extends Mock implements MetaRepository {}

void main() {
  late MockTaskRepo repo;
  late MockMetaRepo meta;
  late AppDatabase stubDb;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = MockTaskRepo();
    meta = MockMetaRepo();
    stubDb = await AppDatabase.open(inMemoryPath: inMemoryDatabasePath);
    when(() => repo.queryAll()).thenAnswer((_) async => const []);
    when(() => repo.queryToday(today: any(named: 'today')))
        .thenAnswer((_) async => const []);
    when(() => repo.queryWeek(start: any(named: 'start'), end: any(named: 'end')))
        .thenAnswer((_) async => const []);
    when(() => meta.queryLists()).thenAnswer((_) async => const [
          ListModel(id: 1, name: '收集箱', isDefault: true),
        ]);
    when(() => meta.queryTags()).thenAnswer((_) async => const []);
  });

  tearDown(() async {
    await stubDb.db.close();
  });

  testWidgets('应用骨架冒烟：底部导航渲染', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final settings = SyncSettings(prefs, InMemoryCredentialStore());
    final container = ProviderContainer(overrides: [
      appDbProvider.overrideWithValue(stubDb),
      taskRepoProvider.overrideWithValue(repo),
      metaRepoProvider.overrideWithValue(meta),
      syncSettingsProvider.overrideWithValue(settings),
      syncManagerProvider.overrideWithValue(
          SyncManager(appDb: stubDb, taskRepository: repo, settings: settings)),
      notificationServiceProvider.overrideWithValue(NotificationService()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const TickTodoApp(locale: Locale('zh')),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('今天'), findsWidgets);
    expect(find.text('最近7天'), findsWidgets);
    expect(find.text('日历'), findsWidgets);
    expect(find.text('全部'), findsWidgets);
  });
}
