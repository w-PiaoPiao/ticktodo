class DayCell {
  const DayCell(this.day, this.inMonth);
  final int day;
  final bool inMonth;
}

/// 月历网格计算：返回 6x7 单元（周一起始），day=0 表示空位
List<DayCell> buildMonthGrid(int year, int month) {
  final first = DateTime(year, month, 1);
  final daysInMonth = DateTime(year, month + 1, 0).day;
  final startWeekday = first.weekday; // 1=周一..7=周日
  final cells = <DayCell>[];
  for (var i = 0; i < startWeekday - 1; i++) {
    cells.add(const DayCell(0, false));
  }
  for (var d = 1; d <= daysInMonth; d++) {
    cells.add(DayCell(d, true));
  }
  while (cells.length % 7 != 0) {
    cells.add(const DayCell(0, false));
  }
  return cells;
}
