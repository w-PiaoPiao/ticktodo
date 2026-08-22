import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/data/repositories/meta_repository.dart';
import 'package:ticktodo/data/repositories/task_repository.dart';
import 'package:ticktodo/features/search/search_screen.dart';

class MockTaskRepo extends Mock implements TaskRepository {}
class MockMetaRepo extends Mock implements MetaRepository {}

void main() {
  late MockTaskRepo repo;
  late MockMetaRepo meta;

  setUpAll(() {
    registerFallbackValue('');
  });

  setUp(() {
    repo = MockTaskRepo();
    meta = MockMetaRepo();
    when(() => meta.queryLists()).thenAnswer((_) async => const []);
  });

  Future<ProviderContainer> pumpSearch(WidgetTester tester) async {
    final container = ProviderContainer(overrides: [
      taskRepoProvider.overrideWithValue(repo),
      metaRepoProvider.overrideWithValue(meta),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SearchScreen()),
    ));
    await tester.pump();
    return container;
  }

  testWidgets('搜索页输入关键词后展示结果', (tester) async {
    when(() => repo.searchTasks('周报')).thenAnswer(
        (_) async => const [Task(id: 3, title: '写周报', listId: 1)]);

    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), '周报');
    // 等待 300ms 防抖 + 查询完成
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('写周报'), findsOneWidget);
  });

  testWidgets('无结果显示空态', (tester) async {
    when(() => repo.searchTasks(any(that: contains('不存在'))))
        .thenAnswer((_) async => const []);

    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), '不存在的东西');
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('没有找到相关任务'), findsOneWidget);
  });

  testWidgets('清空输入回到初始提示', (tester) async {
    when(() => repo.searchTasks('周报')).thenAnswer(
        (_) async => const [Task(id: 3, title: '写周报', listId: 1)]);

    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), '周报');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('写周报'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text('输入关键词开始搜索'), findsOneWidget);
  });
}
