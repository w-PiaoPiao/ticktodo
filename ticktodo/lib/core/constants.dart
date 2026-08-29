import 'package:flutter/material.dart';
import 'package:ticktodo/l10n/app_localizations.dart';

/// 状态/优先级等共用常量
class AppColors {
  static const int overDueRed = 0xFFE04C4C;
}

/// 应用版本（与 pubspec.yaml version 保持同步）
const String kAppVersion = '1.1.0';

/// 软删墓碑保留期：回收站/习惯/打卡/番茄/标签关联的物理清理窗口。
/// 必须大于"其他设备的最长离线时长"——软删行承担同步墓碑职责，
/// 过早物理清理会让长期离线设备重连时把已删数据从远端复活。
const Duration kTombstoneRetention = Duration(days: 90);

/// 清单色板（选择清单/标签颜色用）
const List<int> kPalette = [
  0xFF2F9D45, // 绿
  0xFFE04C4C, // 红
  0xFF4C9AFF, // 蓝
  0xFFF29900, // 橙
  0xFF9B59B6, // 紫
  0xFF00B8A9, // 青
  0xFFE85D9E, // 粉
  0xFF607D8B, // 灰蓝
  0xFF8B7355, // 棕
  0xFF3F51B5, // 靛蓝
];

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

/// 日期徽章文案：今天/明天/昨天/MM月dd日（本地化）
String dateBadge(String dateStr, AppLocalizations l10n, {DateTime? now}) {
  final nowD = now ?? DateTime.now();
  final today = DateTime(nowD.year, nowD.month, nowD.day);
  final d = DateUtilsEx.parseDate(dateStr);
  final todayStr = DateUtilsEx.formatDate(today);

  if (dateStr == todayStr) return l10n.dateBadgeToday;
  if (d == today.add(const Duration(days: 1))) return l10n.dateBadgeTomorrow;
  if (d == today.subtract(const Duration(days: 1))) {
    return l10n.dateBadgeYesterday;
  }
  final sameYear = d.year == nowD.year;
  return sameYear
      ? l10n.dateBadgeMd(d.month, d.day)
      : l10n.dateBadgeYmd(d.year, d.month, d.day);
}

bool isOverdue(String dateStr, {DateTime? now}) {
  final nowD = now ?? DateTime.now();
  final today = DateTime(nowD.year, nowD.month, nowD.day);
  return DateUtilsEx.parseDate(dateStr).isBefore(today);
}
