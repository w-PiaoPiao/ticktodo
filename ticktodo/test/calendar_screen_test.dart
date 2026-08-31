import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/repositories/meta_repository.dart';
import 'package:ticktodo/data/repositories/task_repository.dart';
import 'package:ticktodo/features/calendar/calendar_screen.dart';

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

    testWidgets('initialDate 定位月份并选中该日期', (tester) async {
      await pump(tester, '2026-08-15');
      expect(find.text('2026年8月'), findsOneWidget);
      expect(find.text('8月15日'), findsOneWidget);
    });

    testWidgets('无 initialDate 时选中为空', (tester) async {
      await pump(tester, null);
      expect(find.text('点击日期查看当天任务'), findsOneWidget);
    });
  });
}
