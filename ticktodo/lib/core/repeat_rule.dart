// 简化 RRULE 子集引擎：每天/每周/每月/每年/工作日/自定义周几。
//
// 编码格式（RFC5545 关键词子集）：
// - FREQ=DAILY[;INTERVAL=n]
// - FREQ=WEEKLY[;INTERVAL=n][;BYDAY=MO,TU,...]
// - FREQ=MONTHLY[;INTERVAL=n]
// - FREQ=YEARLY[;INTERVAL=n]

import 'package:ticktodo/l10n/app_localizations.dart';

enum RepeatFreq { daily, weekly, monthly, yearly }

class RepeatRule {
  const RepeatRule({
    required this.freq,
    this.interval = 1,
    this.byWeekdays = const {},
    this.monthDay,
  });

  /// 频率。
  final RepeatFreq freq;

  /// 间隔（每 N 天/周/月/年），>=1。
  final int interval;

  /// 生效星期（DateTime.weekday：1=周一 … 7=周日）；空集合=跟随原日期的星期。
  final Set<int> byWeekdays;

  /// 月重复的锚定日（1..31）：月末钳制时保持原"几号"不漂移
  /// （1/31 → 2/28 → 3/31，而非 3/28）。null=跟随当前到期日（旧行为）。
  final int? monthDay;

  static const _codeOf = {
    1: 'MO', 2: 'TU', 3: 'WE', 4: 'TH', 5: 'FR', 6: 'SA', 7: 'SU',
  };
  static const _dayOfCode = {
    'MO': 1, 'TU': 2, 'WE': 3, 'TH': 4, 'FR': 5, 'SA': 6, 'SU': 7,
  };
  static const _cnOfDay = {
    1: '一', 2: '二', 3: '三', 4: '四', 5: '五', 6: '六', 7: '日',
  };
  static const _enOfDay = {
    1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun',
  };

  String encode() {
    final f = switch (freq) {
      RepeatFreq.daily => 'DAILY',
      RepeatFreq.weekly => 'WEEKLY',
      RepeatFreq.monthly => 'MONTHLY',
      RepeatFreq.yearly => 'YEARLY',
    };
    final parts = <String>['FREQ=$f'];
    if (interval != 1) parts.add('INTERVAL=$interval');
    if (byWeekdays.isNotEmpty) {
      final days = byWeekdays.toList()..sort();
      parts.add('BYDAY=${days.map((d) => _codeOf[d]).join(',')}');
    }
    if (freq == RepeatFreq.monthly && monthDay != null) {
      parts.add('BYMONTHDAY=$monthDay');
    }
    return parts.join(';');
  }

  static RepeatRule? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    RepeatFreq? freq;
    var interval = 1;
    var byDays = <int>{};
    int? monthDay;
    for (final part in raw.split(';')) {
      final i = part.indexOf('=');
      if (i <= 0) continue;
      final key = part.substring(0, i).trim().toUpperCase();
      final value = part.substring(i + 1).trim();
      switch (key) {
        case 'FREQ':
          freq = switch (value.toUpperCase()) {
            'DAILY' => RepeatFreq.daily,
            'WEEKLY' => RepeatFreq.weekly,
            'MONTHLY' => RepeatFreq.monthly,
            'YEARLY' => RepeatFreq.yearly,
            _ => null,
          };
        case 'INTERVAL':
          interval = int.tryParse(value) ?? 1;
          if (interval < 1) interval = 1;
        case 'BYDAY':
          byDays = value
              .split(',')
              .map((s) => _dayOfCode[s.trim().toUpperCase()])
              .whereType<int>()
              .toSet();
        case 'BYMONTHDAY':
          final d = int.tryParse(value);
          monthDay = (d != null && d >= 1 && d <= 31) ? d : null;
      }
    }
    if (freq == null) return null;
    return RepeatRule(
        freq: freq, interval: interval, byWeekdays: byDays, monthDay: monthDay);
  }

  /// 本地化标签（列表行与详情页展示）。
  String label(AppLocalizations l10n) {
    final zhMode = l10n.localeName.startsWith('zh');
    String weeklyLabel(String days, int interval) => zhMode
        ? (interval == 1
            ? '每$days'
            : '每$days · 每 $interval 周')
        : (interval == 1
            ? l10n.repeatEveryWeek
            : l10n.repeatEveryNWeeks(interval));
    if (freq == RepeatFreq.daily) {
      return interval == 1
          ? l10n.repeatEveryDay
          : l10n.repeatEveryNDays(interval);
    }
    if (freq == RepeatFreq.weekly) {
      const workdays = {1, 2, 3, 4, 5};
      if (_sameSet(byWeekdays, workdays)) return l10n.repeatWorkdays;
      if (byWeekdays.isNotEmpty) {
        final days = (byWeekdays.toList()..sort())
            .map((d) => zhMode ? '周${_cnOfDay[d]}' : _enOfDay[d])
            .join('、');
        return weeklyLabel(days, interval);
      }
      return interval == 1
          ? l10n.repeatEveryWeek
          : l10n.repeatEveryNWeeks(interval);
    }
    if (freq == RepeatFreq.monthly) {
      return interval == 1
          ? l10n.repeatEveryMonth
          : l10n.repeatEveryNMonths(interval);
    }
    return interval == 1
        ? l10n.repeatEveryYear
        : l10n.repeatEveryNYears(interval);
  }

  /// 根据当前到期日计算下一次到期（纯函数）。
  DateTime nextDue(DateTime currentDue) {
    switch (freq) {
      case RepeatFreq.daily:
        return DateTime(
            currentDue.year, currentDue.month, currentDue.day + interval);
      case RepeatFreq.weekly:
        if (byWeekdays.isEmpty) {
          return DateTime(currentDue.year, currentDue.month,
              currentDue.day + 7 * interval);
        }
        // 锚定当前周（周一为一周起点）：先在本周剩余日里找下一个命中日，
        // 找不到则跳到第 interval 周后的第一个命中日——保证"每 N 周"
        // 的跨周间隔语义（旧实现会退化为每周都有）。
        for (var d = 1; d <= 7 - currentDue.weekday; d++) {
          final cand =
              DateTime(currentDue.year, currentDue.month, currentDue.day + d);
          if (byWeekdays.contains(cand.weekday)) return cand;
        }
        final nextWeekMonday = DateTime(
            currentDue.year,
            currentDue.month,
            currentDue.day - (currentDue.weekday - 1) + 7 * interval);
        for (var i = 0; i < 7; i++) {
          final cand = DateTime(nextWeekMonday.year, nextWeekMonday.month,
              nextWeekMonday.day + i);
          if (byWeekdays.contains(cand.weekday)) return cand;
        }
        return DateTime(currentDue.year, currentDue.month,
            currentDue.day + 7 * interval); // 兜底（不可达：集合非空必有一命中）
      case RepeatFreq.monthly:
        var y = currentDue.year;
        var m = currentDue.month + interval;
        while (m > 12) {
          m -= 12;
          y++;
        }
        final lastDay = DateTime(y, m + 1, 0).day;
        // 有锚定日（BYMONTHDAY）按锚钳制：短月钳到月末但不丢失原"几号"
        final anchor = monthDay ?? currentDue.day;
        final day = anchor > lastDay ? lastDay : anchor;
        return DateTime(y, m, day);
      case RepeatFreq.yearly:
        final y = currentDue.year + interval;
        final lastDay = DateTime(y, currentDue.month + 1, 0).day;
        final day = currentDue.day > lastDay ? lastDay : currentDue.day;
        return DateTime(y, currentDue.month, day);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is RepeatRule &&
      other.freq == freq &&
      other.interval == interval &&
      other.monthDay == monthDay &&
      _sameSet(other.byWeekdays, byWeekdays);

  @override
  int get hashCode {
    final days = (byWeekdays.toList()..sort()).join(',');
    return Object.hash(freq, interval, days, monthDay);
  }
}

bool _sameSet(Set<int> a, Set<int> b) =>
    a.length == b.length && a.containsAll(b);

/// 详情页重复选择器的预设项。
const List<RepeatRule> kRepeatPresets = [
  RepeatRule(freq: RepeatFreq.daily),
  RepeatRule(freq: RepeatFreq.weekly),
  RepeatRule(freq: RepeatFreq.weekly, byWeekdays: {1, 2, 3, 4, 5}),
  RepeatRule(freq: RepeatFreq.monthly),
  RepeatRule(freq: RepeatFreq.yearly),
];
