import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/features/calendar/month_grid.dart';
import 'package:ticktodo/features/detail/task_detail_screen.dart';
import 'package:ticktodo/features/shared/task_list_view.dart';
import 'package:ticktodo/l10n/app_localizations.dart';

/// 网格范围内（固定 6 行，含前后月填充日）的到期任务：
/// 日历圆点与选中日期任务列表都基于它。
final monthTasksProvider =
    FutureProvider.family<List<Task>, DateTime>((ref, month) async {
  ref.watch(taskMutationProvider);
  final repo = ref.read(taskRepoProvider);
  final cells = buildMonthGrid(month.year, month.month);
  final start = cells.first.date;
  final end = cells.last.date;
  final tasks = await repo.queryWeek(
    start: DateUtilsEx.formatDate(start),
    end: DateUtilsEx.formatDate(end),
  );
  return tasks;
});

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.initialDate});

  /// 小部件点击传入的日期（yyyy-MM-dd），打开时定位到该日
  final String? initialDate;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDate;
    if (d != null && d.isNotEmpty) {
      final dt = DateUtilsEx.parseDate(d);
      _month = DateTime(dt.year, dt.month);
      _selectedDay = dt;
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final tasks = ref.watch(monthTasksProvider(_month)).valueOrNull ?? const [];
    final byDate = <String, List<Task>>{};
    for (final t in tasks) {
      if (t.dueDate != null) {
        byDate.putIfAbsent(t.dueDate!, () => []).add(t);
      }
    }

    final cells = buildMonthGrid(_month.year, _month.month);
    final now = DateTime.now();
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
            Text(l10n.calendarMonthTitle(_month.year, _month.month),
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _changeMonth(1),
            ),
            if (!(_month.year == now.year && _month.month == now.month))
              TextButton(
                  onPressed: () => _changeMonth(0),
                  child: Text(l10n.calendarToday)),
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
                for (final w in (l10n.localeName.startsWith('zh')
                    ? const ['一', '二', '三', '四', '五', '六', '日']
                    : const ['M', 'T', 'W', 'T', 'F', 'S', 'S']))
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
          // 网格：固定 6 行 × 固定行高，保证完整显示当月（如 31 日）
          // 且不挤压下方任务列表
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const cellHeight = 44.0;
                const mainSpacing = 4.0;
                final aspect =
                    (constraints.maxWidth / 7) / cellHeight;
                return SizedBox(
                  height: 6 * cellHeight + 5 * mainSpacing,
                  child: GridView.count(
                    crossAxisCount: 7,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: mainSpacing,
                    childAspectRatio: aspect,
                    children: [
                      for (final cell in cells)
                        _DayCellWidget(
                          cell: cell,
                          isToday: DateUtilsEx.formatDate(cell.date) ==
                              DateUtilsEx.formatDate(now),
                          isSelected: selectedStr != null &&
                              selectedStr ==
                                  DateUtilsEx.formatDate(cell.date),
                          hasTask:
                              byDate.containsKey(DateUtilsEx.formatDate(cell.date)),
                          onTap: () => setState(() {
                            _selectedDay = cell.date;
                            // 点到前后月填充日时切换到对应月份
                            if (cell.date.month != _month.month ||
                                cell.date.year != _month.year) {
                              _month =
                                  DateTime(cell.date.year, cell.date.month);
                            }
                          }),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 24),
          // 选中日期的任务
          if (selectedStr != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(dateBadge(selectedStr, AppLocalizations.of(context)),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.calendarAddTask),
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
                    emptyTitle: l10n.calendarDayEmpty,
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
              '${cell.date.day}',
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
        AppLocalizations.of(context).calendarNoSelection,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }
}
