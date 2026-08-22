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
import 'package:ticktodo/features/shared/task_list_view.dart';
import 'package:ticktodo/notifications/notification_service.dart';
import 'package:ticktodo/sync/sync_manager.dart';
import 'package:ticktodo/sync/sync_settings.dart';

class MockTaskRepo extends Mock implements TaskRepository {}
class MockMetaRepo extends Mock implements MetaRepository {}

void main() {
  late AppDatabase stubDb;
  late MockTaskRepo repo;
  late MockMetaRepo meta;
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
    meta = MockMetaRepo();
    when(() => meta.queryLists()).thenAnswer((_) async =>
        const [ListModel(id: 1, name: '收集箱', color: 0xFF2F9D45, isDefault: true)]);
  });

  tearDown(() async {
    await stubDb.db.close();
  });

  Future<void> pumpList(WidgetTester tester, List<Task> tasks) async {
    final settings = SyncSettings(prefs);
    final container = ProviderContainer(overrides: [
      appDbProvider.overrideWithValue(stubDb),
      taskRepoProvider.overrideWithValue(repo),
      metaRepoProvider.overrideWithValue(meta),
      notificationServiceProvider.overrideWithValue(NotificationService()),
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
      child: MaterialApp(
        home: Scaffold(
          body: TaskListView(tasks: tasks, showCompleted: false),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('长按进入多选，批量软删除', (tester) async {
    const a = Task(id: 11, title: '任务A', listId: 1);
    const b = Task(id: 12, title: '任务B', listId: 1);
    when(() => repo.bulkSoftDelete(any())).thenAnswer((_) async {});
    await pumpList(tester, [a, b]);

    // 长按第一个任务 → 出现多选操作栏
    await tester.longPress(find.text('任务A'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('删除'), findsOneWidget);

    // 多选模式下点按第二个任务加入选中
    await tester.tap(find.text('任务B'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNWidgets(2));

    // 点删除并确认
    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除').last);
    await tester.pumpAndSettle();

    verify(() => repo.bulkSoftDelete([11, 12])).called(1);
    // 操作完成后退出多选，操作栏消失
    expect(find.byTooltip('删除'), findsNothing);
  });

  testWidgets('取消多选恢复正常点按行为', (tester) async {
    const a = Task(id: 13, title: '任务C', listId: 1);
    when(() => repo.bulkSoftDelete(any())).thenAnswer((_) async {});
    await pumpList(tester, [a]);

    await tester.longPress(find.text('任务C'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('取消多选'));
    await tester.pumpAndSettle();

    // 操作栏消失
    expect(find.byTooltip('删除'), findsNothing);
    // 勾选框恢复（check key 可见）
    expect(find.byKey(const ValueKey('check-13')), findsOneWidget);
  });

  testWidgets('多选下批量移动清单', (tester) async {
    const a = Task(id: 14, title: '任务D', listId: 1);
    when(() => repo.bulkMoveToList(any(), any())).thenAnswer((_) async {});
    await pumpList(tester, [a]);

    await tester.longPress(find.text('任务D'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('移动到清单'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('收集箱'));
    await tester.pumpAndSettle();

    verify(() => repo.bulkMoveToList([14], 1)).called(1);
  });
}
