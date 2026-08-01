import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/list_model.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/data/repositories/meta_repository.dart';
import 'package:ticktodo/data/repositories/task_repository.dart';
import 'package:ticktodo/features/today/today_screen.dart';
import 'package:ticktodo/notifications/notification_service.dart';
import 'package:ticktodo/sync/sync_manager.dart';
import 'package:ticktodo/sync/sync_settings.dart';

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
    when(() => meta.queryLists()).thenAnswer((_) async => const [
          ListModel(id: 1, name: '收集箱', isDefault: true),
        ]);
    when(() => meta.queryTags()).thenAnswer((_) async => const []);
  });

  tearDown(() async {
    await stubDb.db.close();
  });

  Future<void> pumpToday(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    final settings = SyncSettings(prefs);
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
      child: const MaterialApp(home: TodayScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('今天视图渲染空状态', (tester) async {
    when(() => repo.queryToday(today: any(named: 'today')))
        .thenAnswer((_) async => const []);
    await pumpToday(tester);
    expect(find.text('今天没有任务'), findsOneWidget);
  });

  testWidgets('今天视图显示到期任务并可勾选', (tester) async {
    final task = Task(
      id: 7,
      title: '写周报',
      listId: 1,
      dueDate: DateTime.now().toString().substring(0, 10),
    );
    when(() => repo.queryToday(today: any(named: 'today')))
        .thenAnswer((_) async => [task]);
    when(() => repo.toggleComplete(any(), any())).thenAnswer((_) async {});
    await pumpToday(tester);
    expect(find.text('写周报'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('check-7')));
    await tester.pump();
    verify(() => repo.toggleComplete(7, true)).called(1);
  });
}
