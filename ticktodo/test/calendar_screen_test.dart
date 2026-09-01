import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/data/repositories/meta_repository.dart';
import 'package:ticktodo/data/repositories/task_repository.dart';
import 'package:ticktodo/features/calendar/calendar_screen.dart';
import 'package:ticktodo/l10n/app_localizations.dart';

import 'support/test_app.dart';
import 'package:ticktodo/features/calendar/month_grid.dart';

class MockTaskRepo extends Mock implements TaskRepository {}
class MockMetaRepo extends Mock implements MetaRepository {}

void main() {
  group('MonthGrid', () {
    test('2026年8月：周六开始，固定42格，31日完整显示', () {
      final cells = buildMonthGrid(2026, 8);
      expect(cells.length, 42);
      // 头部用 7 月填充（7月27日周一 ~ 7月31日）
      expect(cells[0].date, DateTime(2026, 7, 27));
      expect(cells[0].inMonth, false);
      expect(cells[5].date, DateTime(2026, 8, 1));
      expect(cells[5].inMonth, true);
      // 31 日在网格内且属于本月（8月1日=周六在 index 5，31日 = index 5+30）
      expect(cells[35].date, DateTime(2026, 8, 31));
      expect(cells[35].inMonth, true);
      // 尾部用 9 月填充（9月1日 ~ 9月6日）
      expect(cells[36].date, DateTime(2026, 9, 1));
      expect(cells[36].inMonth, false);
      expect(cells[41].date, DateTime(2026, 9, 6));
      expect(cells.where((c) => c.inMonth).length, 31);
    });

    test('2026年2月：周日开始，28天，尾部用3月填充到6行', () {
      final cells = buildMonthGrid(2026, 2);
      expect(cells.length, 42);
      expect(cells[0].date, DateTime(2026, 1, 26));
      expect(cells[6].date, DateTime(2026, 2, 1));
      expect(cells[6].inMonth, true);
      expect(cells[33].date, DateTime(2026, 2, 28));
      expect(cells[34].date, DateTime(2026, 3, 1));
      expect(cells[34].inMonth, false);
      expect(cells.where((c) => c.inMonth).length, 28);
    });

    test('边界：2026年1月 周四开始，跨年填充（2025年12月）', () {
      final cells = buildMonthGrid(2026, 1);
      expect(cells.length, 42);
      expect(cells[0].date, DateTime(2025, 12, 29));
      expect(cells[0].inMonth, false);
      expect(cells[3].date, DateTime(2026, 1, 1));
      expect(cells[3].inMonth, true);
      expect(cells.where((c) => c.inMonth).length, 31);
    });
  });

  group('CalendarScreen', () {
    late MockTaskRepo repo;
    late MockMetaRepo meta;
    late AppDatabase stubDb;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      repo = MockTaskRepo();
      meta = MockMetaRepo();
      stubDb = await AppDatabase.open(inMemoryPath: inMemoryDatabasePath);
      when(() => repo.queryWeek(start: any(named: 'start'), end: any(named: 'end')))
          .thenAnswer((_) async => const []);
      when(() => meta.queryLists()).thenAnswer((_) async => const []);
      when(() => meta.queryTags()).thenAnswer((_) async => const []);
    });

    tearDown(() async {
      await stubDb.db.close();
    });

    Future<void> pump(WidgetTester tester, String? initialDate) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(overrides: [
        appDbProvider.overrideWithValue(stubDb),
        taskRepoProvider.overrideWithValue(repo),
        metaRepoProvider.overrideWithValue(meta),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: testApp(CalendarScreen(initialDate: initialDate)),
      ));
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('initialDate 定位月份并自动弹出当日弹层', (tester) async {
      await pump(tester, '2026-08-15');
      await tester.pumpAndSettle();
      expect(find.text('2026年8月'), findsOneWidget);
      final l10n =
          AppLocalizations.of(tester.element(find.byType(CalendarScreen)));
      expect(find.text(dateBadge('2026-08-15', l10n, now: DateTime.now())),
          findsOneWidget); // 弹层日期标题
      expect(find.text('当天没有任务'), findsOneWidget);
    });

    testWidgets('点击日期弹出当日任务弹层', (tester) async {
      await pump(tester, null);
      // 初始未打开弹层
      expect(find.text('当天没有任务'), findsNothing);
      await tester.tap(find.text('16'));
      await tester.pumpAndSettle();
      // 标题跟随 dateBadge 规则（今天/明天/昨天/M月d日），避免真实时钟撞日脆弱
      final l10n =
          AppLocalizations.of(tester.element(find.byType(CalendarScreen)));
      final now = DateTime.now();
      expect(
          find.text(dateBadge(
              DateUtilsEx.formatDate(DateTime(now.year, now.month, 16)),
              l10n,
              now: now)),
          findsOneWidget);
      expect(find.text('当天没有任务'), findsOneWidget);
    });

    testWidgets('日期卡片显示任务摘要条目与溢出计数', (tester) async {
      final day = DateUtilsEx.formatDate(DateTime(2026, 9, 16));
      final tasks = [
        const Task(
            id: 1,
            title: '买牛奶',
            listId: 1,
            dueDate: '2026-09-16',
            priority: TaskPriority.high),
        for (var i = 0; i < 5; i++)
          Task(id: 10 + i, title: '长任务标题$i', listId: 1, dueDate: day),
      ];
      when(() => repo.queryWeek(
              start: any(named: 'start'), end: any(named: 'end')))
          .thenAnswer((_) async => tasks);
      await pump(tester, null);
      await tester.pumpAndSettle();
      // 网格内直接可见摘要 chip（无需点开日期）
      expect(find.text('买牛奶'), findsOneWidget);
      // 每格最多 4 条：6 条任务溢出 2 条
      expect(find.text('+2'), findsOneWidget);
    });
  });
}
