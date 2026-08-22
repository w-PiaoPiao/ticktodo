import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/data/repositories/task_repository.dart';
import 'package:ticktodo/features/trash/trash_screen.dart';
import 'package:ticktodo/sync/sync_manager.dart';
import 'package:ticktodo/sync/sync_settings.dart';

class MockTaskRepo extends Mock implements TaskRepository {}

void main() {
  late AppDatabase stubDb;
  late MockTaskRepo repo;
  late SharedPreferences prefs;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    registerFallbackValue(<int>[]);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    stubDb = await AppDatabase.open(inMemoryPath: inMemoryDatabasePath);
    repo = MockTaskRepo();
  });

  tearDown(() async {
    await stubDb.db.close();
  });

  Future<void> pumpTrash(WidgetTester tester) async {
    final settings = SyncSettings(prefs);
    final container = ProviderContainer(overrides: [
      appDbProvider.overrideWithValue(stubDb),
      taskRepoProvider.overrideWithValue(repo),
      syncSettingsProvider.overrideWithValue(settings),
      syncManagerProvider.overrideWithValue(SyncManager(
        appDb: stubDb,
        taskRepository: repo,
        settings: settings,
      )),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TrashScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('空回收站显示空状态', (tester) async {
    when(() => repo.queryDeleted()).thenAnswer((_) async => []);
    await pumpTrash(tester);
    expect(find.text('回收站为空'), findsOneWidget);
  });

  testWidgets('已删除任务可恢复并刷新列表', (tester) async {
    final deletedAt = DateTime.now().millisecondsSinceEpoch;
    var result = <Task>[
      Task(id: 7, title: '被删任务', listId: 1, deletedAt: deletedAt)
    ];
    when(() => repo.queryDeleted()).thenAnswer((_) async => result);
    when(() => repo.restoreTask(any())).thenAnswer((_) async {
      result = [];
    });

    await pumpTrash(tester);
    expect(find.text('被删任务'), findsOneWidget);

    await tester.tap(find.byTooltip('恢复'));
    await tester.pumpAndSettle();

    verify(() => repo.restoreTask(7)).called(1);
    expect(find.text('被删任务'), findsNothing); // 重载后为空
  });

  testWidgets('彻底删除需确认并移除记录', (tester) async {
    final deletedAt = DateTime.now().millisecondsSinceEpoch;
    var result = <Task>[
      Task(id: 8, title: '将消失', listId: 1, deletedAt: deletedAt)
    ];
    when(() => repo.queryDeleted()).thenAnswer((_) async => result);
    when(() => repo.hardDeleteTasks(any())).thenAnswer((_) async {
      result = [];
    });

    await pumpTrash(tester);

    await tester.tap(find.byTooltip('彻底删除'));
    await tester.pumpAndSettle();
    // 确认对话框
    await tester.tap(find.widgetWithText(TextButton, '彻底删除').last);
    await tester.pumpAndSettle();

    verify(() => repo.hardDeleteTasks([8])).called(1);
    expect(find.text('回收站为空'), findsOneWidget);
  });
}
