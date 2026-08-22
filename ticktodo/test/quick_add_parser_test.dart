import 'package:flutter_test/flutter_test.dart';
import 'package:ticktodo/core/quick_add_parser.dart';
import 'package:ticktodo/data/models/task.dart';

void main() {
  // 2026-08-22 是周六
  final now = DateTime(2026, 8, 22);

  test('纯文本不解析任何内容', () {
    final d = QuickAddParser.parse('买牛奶', now: now);
    expect(d.title, '买牛奶');
    expect(d.dueDate, isNull);
    expect(d.dueTime, isNull);
    expect(d.priority, TaskPriority.none);
    expect(d.tagNames, isEmpty);
  });

  test('明天 + 下午时间', () {
    final d = QuickAddParser.parse('明天下午3点开会', now: now);
    expect(d.title, '开会');
    expect(d.dueDate, '2026-08-23');
    expect(d.dueTime, '15:00');
  });

  test('周X 解析（周六输入周五 → 下一个周五）', () {
    final d = QuickAddParser.parse('周五健身', now: now);
    expect(d.title, '健身');
    expect(d.dueDate, '2026-08-28');
  });

  test('“周期”不误判为周X', () {
    final d = QuickAddParser.parse('写周期报告', now: now);
    expect(d.title, '写周期报告');
    expect(d.dueDate, isNull);
  });

  test('绝对时间 HH:mm', () {
    final d = QuickAddParser.parse('明天 9:00 站会', now: now);
    expect(d.title, '站会');
    expect(d.dueDate, '2026-08-23');
    expect(d.dueTime, '09:00');
  });

  test('晚上11点半 → 23:30', () {
    final d = QuickAddParser.parse('晚上11点半吃药', now: now);
    expect(d.title, '吃药');
    expect(d.dueTime, '23:30');
  });

  test('今天晚上8点', () {
    final d = QuickAddParser.parse('今天晚上8点跑步', now: now);
    expect(d.title, '跑步');
    expect(d.dueDate, '2026-08-22');
    expect(d.dueTime, '20:00');
  });

  test('标签解析（多个）', () {
    final d = QuickAddParser.parse('买菜 #生活 #采购', now: now);
    expect(d.title, '买菜');
    expect(d.tagNames, ['生活', '采购']);
  });

  test('全角叹号优先级', () {
    final d = QuickAddParser.parse('交房租！高', now: now);
    expect(d.priority, TaskPriority.high);
    expect(d.title, '交房租');
  });

  test('半角叹号优先级低', () {
    final d = QuickAddParser.parse('刷剧 !低', now: now);
    expect(d.priority, TaskPriority.low);
    expect(d.title, '刷剧');
  });

  test('X月X日（今年未过）', () {
    final d = QuickAddParser.parse('9月10日 教师节活动', now: now);
    expect(d.dueDate, '2026-09-10');
    expect(d.title, '教师节活动');
  });

  test('X月X日（今年已过 → 明年）', () {
    final d = QuickAddParser.parse('1月1日 元旦', now: now);
    expect(d.dueDate, '2027-01-01');
  });

  test('ISO 日期', () {
    final d = QuickAddParser.parse('2026-10-01 国庆出游', now: now);
    expect(d.dueDate, '2026-10-01');
    expect(d.title, '国庆出游');
  });

  test('组合解析', () {
    final d = QuickAddParser.parse('明天下午3点 项目评审 #工作 ！高', now: now);
    expect(d.title, '项目评审');
    expect(d.dueDate, '2026-08-23');
    expect(d.dueTime, '15:00');
    expect(d.tagNames, ['工作']);
    expect(d.priority, TaskPriority.high);
  });

  test('“下午茶”不误判时间', () {
    final d = QuickAddParser.parse('喝下午茶', now: now);
    expect(d.title, '喝下午茶');
    expect(d.dueTime, isNull);
  });

  test('空输入返回空草稿', () {
    expect(QuickAddParser.parse('', now: now).title, '');
    expect(QuickAddParser.parse('   ', now: now).title, '');
  });
}
