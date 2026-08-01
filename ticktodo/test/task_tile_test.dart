import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/widgets/empty_state.dart';
import 'package:ticktodo/widgets/task_tile.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: ListView(children: [child])));

  group('TaskTile', () {
    testWidgets('正常渲染标题与勾选框', (tester) async {
      final task = Task(title: '买牛奶', listId: 1);
      await tester.pumpWidget(wrap(TaskTile(task: task)));
      expect(find.text('买牛奶'), findsOneWidget);
      expect(find.byType(Dismissible), findsOneWidget);
    });

    testWidgets('完成状态有删除线', (tester) async {
      final task = Task(title: '已完成', listId: 1, completed: true);
      await tester.pumpWidget(wrap(TaskTile(task: task)));
      final text = tester.widget<Text>(find.text('已完成'));
      expect(text.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('过期日期显示红色", 今天不红', (tester) async {
      final now = DateTime(2026, 8, 1);
      final overdue = Task(title: '过期', listId: 1, dueDate: '2026-07-31');
      final today = Task(title: '今日任务', listId: 1, dueDate: '2026-08-01');
      await tester.pumpWidget(
          wrap(Column(children: [TaskTile(task: overdue, now: now), TaskTile(task: today, now: now)])));
      final overdueBadge = tester.widget<Text>(find.text('昨天'));
      expect(overdueBadge.style?.color, const Color(0xFFE04C4C));
      final todayBadge = tester.widget<Text>(find.text('今天'));
      expect(todayBadge.style?.color, isNot(const Color(0xFFE04C4C)));
    });

    testWidgets('勾选回调触发', (tester) async {
      final task = Task(title: 't', listId: 1, id: 7);
      var toggled = false;
      await tester.pumpWidget(wrap(TaskTile(task: task, onToggle: () => toggled = true)));
      await tester.tap(find.byKey(const ValueKey('check-7')));
      expect(toggled, true);
    });

    testWidgets('滑动删除回调', (tester) async {
      final task = Task(title: 't', listId: 1);
      var deleted = false;
      await tester.pumpWidget(wrap(TaskTile(task: task, onDelete: () => deleted = true)));
      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(deleted, true);
    });

    testWidgets('优先级 flag 显示', (tester) async {
      final task = Task(title: 't', listId: 1, priority: TaskPriority.high);
      await tester.pumpWidget(wrap(TaskTile(task: task)));
      expect(find.byIcon(Icons.flag), findsOneWidget);
    });
  });

  group('EmptyState', () {
    testWidgets('渲染标题与副标题', (tester) async {
      await tester.pumpWidget(wrap(const EmptyState(
          icon: Icons.inbox, title: '没有任务', subtitle: '点右下角添加')));
      expect(find.text('没有任务'), findsOneWidget);
      expect(find.text('点右下角添加'), findsOneWidget);
    });
  });
}
