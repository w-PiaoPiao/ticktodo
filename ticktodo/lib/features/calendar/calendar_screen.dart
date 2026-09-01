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
/// 日摘要卡片与当天任务弹层都基于它。
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

/// 当天卡片内排序：未完成在前（优先级高→低、时间早→晚），已完成垫底。
List<Task> sortDayTasks(List<Task> tasks) {
  final list = [...tasks];
  list.sort((a, b) {
    if (a.completed != b.completed) return a.completed ? 1 : -1;
    final p = b.priority.value.compareTo(a.priority.value);
    if (p != 0) return p;
    return (a.dueTime ?? '99:99').compareTo(b.dueTime ?? '99:99');
  });
  return list;
}

/// 月视图日历：每个日期是一格「当日任务摘要小卡片」，
/// 一眼可扫整月事项分布；点击日期弹出当天完整列表。
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.initialDate});

  /// 小部件点击传入的日期（yyyy-MM-dd），打开时定位并弹出该日
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
      // 小部件跳转语义 = 直接看那一天：首帧后自动弹出当日弹层
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openDaySheet(dt);
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = day;
      // 点到前后月填充日时切换到对应月份
      if (day.month != _month.month || day.year != _month.year) {
        _month = DateTime(day.year, day.month);
      }
    });
    _openDaySheet(day);
  }

  Future<void> _openDaySheet(DateTime day) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DaySheet(day: day),
    );
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
    final todayStr = DateUtilsEx.formatDate(now);
    final selectedStr = _selectedDay == null
        ? null
        : DateUtilsEx.formatDate(_selectedDay!);
    // 本月事项总数（不含前后月填充日）
    final monthCount = tasks
        .where((t) =>
            t.dueDate != null &&
            DateTime.parse(t.dueDate!).year == _month.year &&
            DateTime.parse(t.dueDate!).month == _month.month)
        .length;

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
            if (monthCount > 0) ...[
              const SizedBox(width: 8),
              Text('$monthCount',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
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
          // 摘要卡片网格：6 行铺满剩余高度，格内自适应显示任务条目
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 6.0;
                  final cellW = (constraints.maxWidth - 6 * spacing) / 7;
                  final cellH = (constraints.maxHeight - 5 * spacing) / 6;
                  return GridView.count(
                    crossAxisCount: 7,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: cellW / cellH,
                    children: [
                      for (final cell in cells)
                        DayTaskCard(
                          cell: cell,
                          tasks: sortDayTasks(
                              byDate[DateUtilsEx.formatDate(cell.date)] ??
                                  const []),
                          isToday:
                              DateUtilsEx.formatDate(cell.date) == todayStr,
                          isSelected: selectedStr != null &&
                              selectedStr ==
                                  DateUtilsEx.formatDate(cell.date),
                          onTap: () => _selectDay(cell.date),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单日摘要卡片：日期数字 + 若干条任务 chip（优先级色点 + 标题），
/// 超出格子容量的折叠为右上角「+N」。
class DayTaskCard extends StatelessWidget {
  const DayTaskCard({
    super.key,
    required this.cell,
    required this.tasks,
    required this.isToday,
    required this.isSelected,
    this.onTap,
  });

  final DayCell cell;
  final List<Task> tasks;
  final bool isToday;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final inMonth = cell.inMonth;

    return LayoutBuilder(
      builder: (context, constraints) {
        const headerH = 20.0;
        const chipH = 16.0;
        final maxChips =
            ((constraints.maxHeight - headerH - 4) / chipH).floor().clamp(1, 4);
        final visible = tasks.take(maxChips).toList();
        final overflow = tasks.length - visible.length;

        final card = Container(
          padding: const EdgeInsets.fromLTRB(5, 3, 5, 3),
          decoration: BoxDecoration(
            color: isSelected
                ? scheme.primaryContainer.withValues(alpha: 0.5)
                : inMonth
                    ? scheme.surfaceContainerLow
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: scheme.primary.withValues(alpha: 0.7))
                : inMonth
                    ? Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.35),
                        width: 0.5)
                    : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: headerH,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isToday)
                        Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${cell.date.day}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.bold),
                          ),
                        )
                      else
                        Text(
                          '${cell.date.day}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: inMonth
                                ? theme.textTheme.bodyMedium?.color
                                : scheme.outlineVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (overflow > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '+$overflow',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.outline,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final t in visible) DayTaskChip(task: t)],
                ),
              ),
            ],
          ),
        );

        return Opacity(
          opacity: inMonth ? 1.0 : 0.38,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: card,
            ),
          ),
        );
      },
    );
  }
}

/// 卡片内单条任务摘要：优先级色点 + 标题（单行截断）。
class DayTaskChip extends StatelessWidget {
  const DayTaskChip({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dotColor = task.priority == TaskPriority.none
        ? scheme.outline.withValues(alpha: 0.6)
        : Color(task.priority.colorValue);
    return SizedBox(
      height: 16,
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              task.title.isEmpty
                  ? AppLocalizations.of(context).untitledTask
                  : task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                color: task.completed
                    ? scheme.onSurface.withValues(alpha: 0.38)
                    : scheme.onSurface.withValues(alpha: 0.82),
                decoration: task.completed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 当日任务弹层：日期标题 + 添加按钮 + 完整列表（跟随同步刷新）。
class DaySheet extends ConsumerWidget {
  const DaySheet({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final month = DateTime(day.year, day.month);
    final dayStr = DateUtilsEx.formatDate(day);
    final tasks = ref.watch(monthTasksProvider(month)).valueOrNull ?? const [];
    final dayTasks = sortDayTasks(
        tasks.where((t) => t.dueDate == dayStr).toList(growable: false));

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.62,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
            child: Row(
              children: [
                Text(dateBadge(dayStr, l10n),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                if (dayTasks.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text('${dayTasks.length}',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
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
            child: TaskListView(
              tasks: dayTasks,
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
