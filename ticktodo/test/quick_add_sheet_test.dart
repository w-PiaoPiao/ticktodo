import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/list_model.dart';
import 'package:ticktodo/data/models/tag.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/data/repositories/meta_repository.dart';
import 'package:ticktodo/data/repositories/task_repository.dart';
import 'package:ticktodo/notifications/notification_service.dart';
import 'package:ticktodo/sync/sync_manager.dart';
import 'package:ticktodo/sync/sync_settings.dart';
import 'package:ticktodo/widgets/quick_add_sheet.dart';

class MockTaskRepo extends Mock implements TaskRepository {}
class MockMetaRepo extends Mock implements MetaRepository {}

void main() {
  late AppDatabase stubDb;
  late MockTaskRepo repo;
  late MockMetaRepo meta;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    registerFallbackValue(Task(title: '', listId: 0));
    registerFallbackValue(const Tag(name: ''));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    stubDb = await AppDatabase.open(inMemoryPath: inMemoryDatabasePath);
    repo = MockTaskRepo();
    meta = MockMetaRepo();
    when(() => meta.queryLists()).thenAnswer((_) async =>
        const [ListModel(id: 1, name: '收集箱', color: 0xFF2F9D45, isDefault: true)]);
    when(() => meta.ensureDefaultList()).thenAnswer((_) async => 1);
    when(() => meta.queryTags()).thenAnswer((_) async => const []);
  });

  tearDown(() async {
    await stubDb.db.close();
  });

  Future<void> pumpSheet(WidgetTester tester,
      {bool defaultDueDate = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final settings = SyncSettings(prefs);
    final container = ProviderContainer(overrides: [
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
        home: Builder(builder: (ctx) {
          return Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showQuickAdd(ctx, defaultDueDate: defaultDueDate),
                child: const Text('open'),
              ),
            ),
          );
        }),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('输入文本实时显示解析 chips 并保存创建任务', (tester) async {
    Task? saved;
    when(() => repo.upsertTask(any())).thenAnswer((inv) async {
      saved = inv.positionalArguments[0] as Task;
      return 99;
    });

    await pumpSheet(tester, defaultDueDate: true);

    await tester.enterText(find.byType(TextField), '明天下午3点开会');
    await tester.pump();

    expect(find.text('明天'), findsOneWidget); // 日期 chip
    expect(find.text('15:00'), findsOneWidget); // 时间 chip

    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.title, '开会');
    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    expect(saved!.dueDate,
        '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}');
    expect(saved!.dueTime, '15:00');
    // 底部弹窗已关闭
    expect(find.byType(QuickAddSheet), findsNothing);
  });

  testWidgets('标签自动创建并关联', (tester) async {
    when(() => repo.upsertTask(any())).thenAnswer((_) async => 99);
    var createdTag = false;
    when(() => meta.upsertTag(any())).thenAnswer((inv) async {
      createdTag = (inv.positionalArguments[0] as Tag).name == '生活';
      return 5;
    });
    when(() => meta.linkTaskTag(any(), any())).thenAnswer((_) async {});

    await pumpSheet(tester);

    await tester.enterText(find.byType(TextField), '买菜 #生活');
    await tester.pump();
    expect(find.text('#生活'), findsOneWidget);

    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    verify(() => meta.linkTaskTag(99, 5)).called(1);
    expect(createdTag, isTrue);
  });

  testWidgets('标题为空时添加按钮禁用', (tester) async {
    await pumpSheet(tester);
    final button = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, '添加'));
    expect(button.onPressed, isNull);
  });
}
