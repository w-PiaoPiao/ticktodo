import 'package:flutter_test/flutter_test.dart';
import 'package:ticktodo/core/repeat_rule.dart';
import 'package:ticktodo/l10n/app_localizations.dart';
import 'package:ticktodo/l10n/app_localizations_zh.dart' as zh;

void main() {
  final zhL10n = zh.AppLocalizationsZh();
  group('parse/encode', () {
    test('null/空串/垃圾输入返回 null', () {
      expect(RepeatRule.parse(null), isNull);
      expect(RepeatRule.parse(''), isNull);
      expect(RepeatRule.parse('垃圾'), isNull);
      expect(RepeatRule.parse('FOO=BAR'), isNull);
    });

    test('encode→parse 往返相等', () {
      for (final r in kRepeatPresets) {
        expect(RepeatRule.parse(r.encode()), r);
      }
      const custom =
          RepeatRule(freq: RepeatFreq.weekly, interval: 2, byWeekdays: {1, 3});
      expect(RepeatRule.parse(custom.encode()), custom);
    });

    test('interval 非法值兜底为 1', () {
      final r = RepeatRule.parse('FREQ=DAILY;INTERVAL=0');
      expect(r!.interval, 1);
      expect(RepeatRule.parse('FREQ=DAILY;INTERVAL=abc')!.interval, 1);
    });
  });

  group('nextDue', () {
    test('每天：次日', () {
      const r = RepeatRule(freq: RepeatFreq.daily);
      expect(r.nextDue(DateTime(2026, 8, 22)), DateTime(2026, 8, 23));
    });

    test('每 3 天：+3 天', () {
      const r = RepeatRule(freq: RepeatFreq.daily, interval: 3);
      expect(r.nextDue(DateTime(2026, 8, 22)), DateTime(2026, 8, 25));
    });

    test('每周（无 BYDAY）：+7 天', () {
      const r = RepeatRule(freq: RepeatFreq.weekly);
      expect(r.nextDue(DateTime(2026, 8, 22)), DateTime(2026, 8, 29));
    });

    test('每 2 周：+14 天', () {
      const r = RepeatRule(freq: RepeatFreq.weekly, interval: 2);
      expect(r.nextDue(DateTime(2026, 8, 22)), DateTime(2026, 9, 5));
    });

    test('工作日：周五 → 下周一', () {
      const r = RepeatRule(freq: RepeatFreq.weekly, byWeekdays: {1, 2, 3, 4, 5});
      // 2026-08-21 是周五
      expect(r.nextDue(DateTime(2026, 8, 21)), DateTime(2026, 8, 24));
    });

    test('BYDAY={MO,WE}：周三 → 下一次是下周一', () {
      const r = RepeatRule(freq: RepeatFreq.weekly, byWeekdays: {1, 3});
      // 2026-08-19 是周三
      expect(r.nextDue(DateTime(2026, 8, 19)), DateTime(2026, 8, 24));
    });

    test('每 2 周周一：下一期隔一周（不再退化为每周一）', () {
      const r =
          RepeatRule(freq: RepeatFreq.weekly, interval: 2, byWeekdays: {1});
      // 2026-08-03 是周一
      expect(r.nextDue(DateTime(2026, 8, 3)), DateTime(2026, 8, 17));
    });

    test('每 2 周周一+周三：同周内先走周三，再跳两周后的周一', () {
      const r =
          RepeatRule(freq: RepeatFreq.weekly, interval: 2, byWeekdays: {1, 3});
      // 2026-08-03 周一 → 本周周三
      expect(r.nextDue(DateTime(2026, 8, 3)), DateTime(2026, 8, 5));
      // 周三 → 下一命中日在两周后的那一周
      expect(r.nextDue(DateTime(2026, 8, 5)), DateTime(2026, 8, 17));
    });

    test('每月 BYMONTHDAY 锚：1/31 → 2/28 → 3/31（不漂移）', () {
      final r = RepeatRule.parse('FREQ=MONTHLY;BYMONTHDAY=31');
      expect(r!.nextDue(DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
      expect(r.nextDue(DateTime(2026, 2, 28)), DateTime(2026, 3, 31));
    });

    test('BYMONTHDAY 非法值忽略', () {
      expect(
          RepeatRule.parse('FREQ=MONTHLY;BYMONTHDAY=99')!.monthDay, isNull);
      expect(
          RepeatRule.parse('FREQ=MONTHLY;BYMONTHDAY=abc')!.monthDay, isNull);
    });

    test('每月：月末钳制 1/31 → 2/28', () {
      const r = RepeatRule(freq: RepeatFreq.monthly);
      expect(r.nextDue(DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
    });

    test('每月：普通日期 1/15 → 2/15', () {
      const r = RepeatRule(freq: RepeatFreq.monthly);
      expect(r.nextDue(DateTime(2026, 1, 15)), DateTime(2026, 2, 15));
    });

    test('每年：闰日 2024-02-29 → 2025-02-28 钳制', () {
      const r = RepeatRule(freq: RepeatFreq.yearly);
      expect(r.nextDue(DateTime(2024, 2, 29)), DateTime(2025, 2, 28));
    });

    test('每年：普通日期 2026-05-01 → 2027-05-01', () {
      const r = RepeatRule(freq: RepeatFreq.yearly);
      expect(r.nextDue(DateTime(2026, 5, 1)), DateTime(2027, 5, 1));
    });
  });

  group('label', () {
    AppLocalizations zh() => zhL10n;

    test('预设中文文案', () {
      expect(kRepeatPresets[0].label(zh()), '每天'); // daily
      expect(kRepeatPresets[1].label(zh()), '每周'); // weekly
      expect(kRepeatPresets[2].label(zh()), '工作日'); // workdays
      expect(kRepeatPresets[3].label(zh()), '每月'); // monthly
      expect(kRepeatPresets[4].label(zh()), '每年'); // yearly
    });

    test('自定义周几文案与间隔文案', () {
      const r = RepeatRule(freq: RepeatFreq.weekly, byWeekdays: {1, 3});
      expect(r.label(zh()), '每周一、周三');
      const every2Days = RepeatRule(freq: RepeatFreq.daily, interval: 2);
      expect(every2Days.label(zh()), '每 2 天');
    });
  });
}
