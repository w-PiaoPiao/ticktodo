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
import 'package:ticktodo/features/calendar/month_grid.dart';

class MockTaskRepo extends Mock implements TaskRepository {}
class MockMetaRepo extends Mock implements MetaRepository {}

void main() {
  group('MonthGrid', () {
    test('2026年8月：周六开始，31天，填满整周', () {
      final cells = buildMonthGrid(2026, 8);
      expect(cells.length, 42);
      expect(cells[0].day, 0);
      expect(cells[4].day, 0);
      expect(cells[5].day, 1);
      expect(cells[5].inMonth, true);
      expect(cells.where((c) => c.inMonth).length, 31);
    });

    test('2026年2月：28天，5行', () {
      final cells = buildMonthGrid(2026, 2);
      expect(cells[6].day, 1);
      expect(cells[6].inMonth, true);
      expect(cells.length, 35);
      expect(cells.where((c) => c.inMonth).length, 28);
    });

    test('边界：2026年1月 周四开始', () {
      final cells = buildMonthGrid(2026, 1);
      expect(cells[0].day, 0);
      expect(cells[0].inMonth, false);
      expect(cells[3].day, 1);
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
        child: MaterialApp(
          home: CalendarScreen(initialDate: initialDate),
        ),
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
