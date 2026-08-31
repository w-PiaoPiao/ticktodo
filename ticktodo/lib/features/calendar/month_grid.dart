import 'package:ticktodo/core/constants.dart';

/// 月历单元格：携带完整日期；[inMonth] 为 false 表示前后月填充日期（UI 置灰）。
class DayCell {
  const DayCell(this.date, this.inMonth);
  final DateTime date;
  final bool inMonth;
}

/// 月历网格计算：固定 6x7 = 42 格（周一起始），
/// 头部空位用上月日期、尾部空位用下月日期填充，
/// 保证任何月份都完整显示（如 8 月 31 日不会被挤出网格）。
List<DayCell> buildMonthGrid(int year, int month) {
  final first = DateTime(year, month, 1);
  final startWeekday = first.weekday; // 1=周一..7=周日
  final gridStart = DateUtilsEx.startOfDay(
      first.subtract(Duration(days: startWeekday - 1)));
  return List.generate(42, (i) {
    final date = DateUtilsEx.addDays(gridStart, i);
    return DayCell(date, date.month == month);
  });
}
