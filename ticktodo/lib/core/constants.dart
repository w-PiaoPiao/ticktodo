import 'package:flutter/material.dart';

/// 状态/优先级等共用常量
class AppColors {
  static const int overDueRed = 0xFFE04C4C;
}

/// 日期工具
class DateUtilsEx {
  /// 'yyyy-MM-dd' → DateTime（本地）
  static DateTime parseDate(String s) {
    final parts = s.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  /// DateTime → 'yyyy-MM-dd'
  static String formatDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// 'HH:mm' → DateTime 或 null
  static DateTime? parseTime(String? s) {
    if (s == null) return null;
    final parts = s.split(':');
    return DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
  }

  static String formatTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  static String formatTimeOfDay(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

/// 日期徽章文案：今天/明天/昨天/MM月dd日
String dateBadge(String dateStr, {DateTime? now}) {
  final nowD = now ?? DateTime.now();
  final today = DateTime(nowD.year, nowD.month, nowD.day);
  final d = DateUtilsEx.parseDate(dateStr);
  final todayStr = DateUtilsEx.formatDate(today);

  if (dateStr == todayStr) return '今天';
  if (d == today.add(const Duration(days: 1))) return '明天';
  if (d == today.subtract(const Duration(days: 1))) return '昨天';
  final sameYear = d.year == nowD.year;
  return sameYear ? '${d.month}月${d.day}日' : '${d.year}年${d.month}月${d.day}日';
}

bool isOverdue(String dateStr, {DateTime? now}) {
  final nowD = now ?? DateTime.now();
  final today = DateTime(nowD.year, nowD.month, nowD.day);
  return DateUtilsEx.parseDate(dateStr).isBefore(today);
}
