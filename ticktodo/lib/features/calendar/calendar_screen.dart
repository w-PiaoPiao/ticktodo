import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/features/calendar/month_grid.dart';
import 'package:ticktodo/features/detail/task_detail_screen.dart';
import 'package:ticktodo/features/shared/task_list_view.dart';

/// 月内到期任务（日历圆点 + 点选当天详情）
final monthTasksProvider =
    FutureProvider.family<List<Task>, DateTime>((ref, month) async {
  ref.watch(taskMutationProvider);
  final repo = ref.read(taskRepoProvider);
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 0);
  final tasks = await repo.queryWeek(
    start: DateUtilsEx.formatDate(start),
    end: DateUtilsEx.formatDate(end),
  );
  return tasks;
});

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasks = ref.watch(monthTasksProvider(_month)).valueOrNull ?? const [];
    final byDate = <String, List<Task>>{};
    for (final t in tasks) {
      if (t.dueDate != null) {
        byDate.putIfAbsent(t.dueDate!, () => []).add(t);
      }
    }

    final cells = buildMonthGrid(_month.year, _month.month);
    final now = DateTime.now();
    final todayStr = DateUtilsEx.formatDate(now);
    final selectedStr = _selectedDay == null
        ? null
        : DateUtilsEx.formatDate(_selectedDay!);
    final selectedTasks =
        selectedStr == null ? <Task>[] : (byDate[selectedStr] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeMonth(-1),
            ),
            Text('${_month.year}年${_month.month}月',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _changeMonth(1),
            ),
            if (!(_month.year == now.year && _month.month == now.month))
              TextButton(onPressed: () => _changeMonth(0), child: const Text('今天')),
          ],
        ),
      ),
      body: Column(
        children: [
          // 星期表头
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                for (final w in const ['一', '二', '三', '四', '五', '六', '日'])
                  Expanded(
                    child: Center(
                      child: Text(w,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: theme.colorScheme.outline)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // 网格
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              children: [
                for (final cell in cells)
                  _DayCellWidget(
                    cell: cell,
                    isToday: cell.inMonth &&
                        cell.day == now.day &&
                        _month.year == now.year &&
                        _month.month == now.month,
                    isSelected: cell.inMonth &&
                        selectedStr != null &&
                        selectedStr ==
                            '${_month.year}-${_month.month.toString().padLeft(2, '0')}-${cell.day.toString().padLeft(2, '0')}',
                    hasTask: cell.inMonth &&
                        byDate.containsKey('${_month.year}-'
                            '${_month.month.toString().padLeft(2, '0')}-'
                            '${cell.day.toString().padLeft(2, '0')}'),
                    onTap: cell.inMonth
                        ? () => setState(() => _selectedDay = DateTime(
                            _month.year, _month.month, cell.day))
                        : null,
                  ),
              ],
            ),
          ),
          const Divider(height: 24),
          // 选中日期的任务
          if (selectedStr != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(dateBadge(selectedStr!),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('添加任务'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TaskDetailScreen(
                            taskId: 0, defaultDueDate: true),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: selectedStr == null
                ? const EmptyHint()
                : TaskListView(
                    tasks: selectedTasks,
                    emptyIcon: Icons.event_available,
                    emptyTitle: '当天没有任务',
                    onTapTask: (t) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TaskDetailScreen(taskId: t.id ?? 0),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DayCellWidget extends StatelessWidget {
  const _DayCellWidget({
    required this.cell,
    required this.isToday,
    required this.isSelected,
    required this.hasTask,
    this.onTap,
  });

  final DayCell cell;
  final bool isToday;
  final bool isSelected;
  final bool hasTask;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isToday
        ? theme.colorScheme.primary
        : isSelected
            ? theme.colorScheme.primaryContainer
            : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        alignment: Alignment.center,
        decoration: color == null
            ? null
            : BoxDecoration(
                color: color.withValues(alpha: isToday ? 0.15 : 0.4),
                shape: BoxShape.circle,
              ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              cell.day == 0 ? '' : '${cell.day}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cell.inMonth
                    ? (isToday ? theme.colorScheme.primary : null)
                    : theme.colorScheme.outlineVariant,
                fontWeight: isToday ? FontWeight.bold : null,
              ),
            ),
            if (hasTask)
              Positioned(
                bottom: 2,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '点击日期查看当天任务',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }
}
