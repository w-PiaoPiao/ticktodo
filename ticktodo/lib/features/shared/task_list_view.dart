import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/list_model.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/widgets/empty_state.dart';
import 'package:ticktodo/widgets/task_tile.dart';

/// 通用任务列表：未完成区 + 已完成折叠区 + 空状态
class TaskListView extends ConsumerWidget {
  const TaskListView({
    super.key,
    required this.tasks,
    this.lists,
    this.emptyIcon = Icons.inbox,
    this.emptyTitle = '没有任务',
    this.emptySubtitle,
    this.showCompleted = true,
    this.onTapTask,
    this.now,
  });

  final List<Task> tasks;
  final List<ListModel>? lists;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptySubtitle;
  final bool showCompleted;
  final void Function(Task)? onTapTask;
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(taskRepoProvider);
    final metaRepo = ref.read(metaRepoProvider);
    final allLists = lists ?? ref.watch(listsProvider).valueOrNull ?? [];

    final open = tasks.where((t) => !t.completed).toList()
      ..sort((a, b) {
        final p = b.priority.value.compareTo(a.priority.value);
        if (p != 0) return p;
        return (a.dueDate ?? '9999').compareTo(b.dueDate ?? '9999');
      });
    final done = tasks.where((t) => t.completed).toList();

    ListModel? listOf(int id) {
      for (final l in allLists) {
        if (l.id == id) return l;
      }
      return null;
    }

    if (tasks.isEmpty) {
      return EmptyState(icon: emptyIcon, title: emptyTitle, subtitle: emptySubtitle);
    }

    return ListView(
      children: [
        if (open.isNotEmpty)
          ...open.map((t) => TaskTile(
                task: t,
                list: listOf(t.listId),
                now: now,
                onTap: onTapTask == null ? null : () => onTapTask!(t),
                onToggle: () async {
                  await repo.toggleComplete(t.id!, !t.completed);
                  bumpMutation(ref);
                },
                onDelete: () async {
                  await repo.softDeleteTask(t.id!);
                  bumpMutation(ref);
                },
              )),
        if (open.isNotEmpty && done.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              '已完成 ${done.length}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
        if (done.isNotEmpty && showCompleted)
          ...done.map((t) => TaskTile(
                task: t,
                list: listOf(t.listId),
                now: now,
                onTap: onTapTask == null ? null : () => onTapTask!(t),
                onToggle: () async {
                  await repo.toggleComplete(t.id!, false);
                  bumpMutation(ref);
                },
                onDelete: () async {
                  await repo.softDeleteTask(t.id!);
                  bumpMutation(ref);
                },
              )),
      ],
    );
  }
}
