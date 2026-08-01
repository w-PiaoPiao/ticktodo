import 'package:flutter_test/flutter_test.dart';
import 'package:ticktodo/features/calendar/month_grid.dart';

void main() {
  test('2026年8月：周六开始，31天，填满整周', () {
    final cells = buildMonthGrid(2026, 8);
    expect(cells.length, 42); // 6 行
    // 2026-08-01 是周六，weekday=6 → 前 5 个空位
    expect(cells[0].day, 0);
    expect(cells[4].day, 0);
    expect(cells[5].day, 1);
    expect(cells[5].inMonth, true);
    final days = cells.where((c) => c.inMonth).length;
    expect(days, 31);
  });

  test('2026年2月：28天，周日开始？', () {
    // 2026-02-01 是周日 weekday=7 → 前 6 空位，之后 28 天
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
    expect(cells[3].day, 1); // 周四 weekday=4 → 前 3 空
    expect(cells.where((c) => c.inMonth).length, 31);
  });
}
