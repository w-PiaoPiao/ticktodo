import 'package:flutter/material.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/data/models/list_model.dart';
import 'package:ticktodo/data/models/task.dart';

/// 任务列表行：勾选框 + 标题 + 优先级/日期/清单信息
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    this.list,
    this.subtaskCount = 0,
    this.showListColor = true,
    this.onTap,
    this.onToggle,
    this.onDelete,
    this.now,
    this.selectMode = false,
    this.selected = false,
    this.onToggleSelect,
    this.onLongPress,
  });

  final Task task;
  final ListModel? list;
  final int subtaskCount;
  final bool showListColor;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;
  final DateTime? now;

  /// true 时进入多选模式：leading 变复选框、禁用滑动删除、点按切换选中。
  final bool selectMode;
  final bool selected;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = task.dueDate != null && isOverdue(task.dueDate!, now: now);

    final title = Text(
      task.title,
      style: theme.textTheme.bodyLarge?.copyWith(
        decoration: task.completed ? TextDecoration.lineThrough : null,
        color: task.completed
            ? theme.colorScheme.outline
            : theme.colorScheme.onSurface,
        fontWeight: task.completed ? FontWeight.w400 : FontWeight.w500,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    final dateBadgeWidget = task.dueDate == null
        ? null
        : Text(
            dateBadge(task.dueDate!, now: now),
            style: theme.textTheme.bodySmall?.copyWith(
              color: overdue && !task.completed
                  ? const Color(AppColors.overDueRed)
                  : theme.colorScheme.outline,
            ),
          );

    final timeText = task.dueTime == null
        ? null
        : Text(
            task.dueTime!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: overdue && !task.completed
                  ? const Color(AppColors.overDueRed)
                  : theme.colorScheme.outline,
            ),
          );

    return Dismissible(
      key: ValueKey('task-${task.id}'),
      direction: selectMode ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: const Color(AppColors.overDueRed),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete?.call(),
      child: ListTile(
        onTap: selectMode ? onToggleSelect : onTap,
        onLongPress: onLongPress,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: selectMode
            ? Checkbox(
                value: selected,
                onChanged: (_) => onToggleSelect?.call(),
              )
            : _CheckCircle(
                key: ValueKey('check-${task.id}'),
                completed: task.completed,
                onTap: onToggle,
              ),
        title: title,
        subtitle: (task.note.isNotEmpty ||
                dateBadgeWidget != null ||
                timeText != null ||
                task.repeatRule != null)
            ? Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    if (task.note.isNotEmpty)
                      Flexible(
                        child: Text(
                          task.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ),
                    if (dateBadgeWidget != null) ...[
                      const SizedBox(width: 6),
                      dateBadgeWidget,
                    ],
                    if (timeText != null) ...[
                      const SizedBox(width: 6),
                      timeText,
                    ],
                    if (task.repeatRule != null) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.repeat, size: 14, color: theme.colorScheme.outline),
                    ],
                  ],
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.priority != TaskPriority.none)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.flag,
                  size: 16,
                  color: Color(task.priority.colorValue),
                ),
              ),
            if (subtaskCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  '$subtaskCount',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            if (showListColor && list != null)
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Color(list!.color),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 圆形勾选框
class _CheckCircle extends StatelessWidget {
  const _CheckCircle({super.key, required this.completed, this.onTap});

  final bool completed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: completed ? color : Colors.transparent,
          border: Border.all(
            color: completed ? color : Theme.of(context).colorScheme.outline,
            width: 2,
          ),
        ),
        child: completed
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}
