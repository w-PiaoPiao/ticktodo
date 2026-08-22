import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/list_model.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/widgets/empty_state.dart';
import 'package:ticktodo/widgets/task_tile.dart';

/// 通用任务列表：未完成区 + 已完成折叠区 + 空状态 + 长按多选批量操作。
class TaskListView extends ConsumerStatefulWidget {
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
  ConsumerState<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends ConsumerState<TaskListView> {
  final Set<int> _selectedIds = {};

  bool get _selecting => _selectedIds.isNotEmpty;

  void _toggleSelect(int id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  Future<void> _runBulk(Future<void> Function() op) async {
    await op();
    if (!mounted) return;
    setState(_selectedIds.clear);
    bumpMutation(ref);
  }

  Future<void> _bulkDelete() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除 ${ids.length} 个任务'),
        content: const Text('删除后可在回收站恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _runBulk(() => ref.read(taskRepoProvider).bulkSoftDelete(ids));
  }

  Future<void> _bulkMove() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final lists = widget.lists ?? ref.read(listsProvider).valueOrNull ?? [];
    if (lists.isEmpty) return;
    final target = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('移动到清单',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final l in lists)
              ListTile(
                leading: Icon(Icons.circle, size: 12, color: Color(l.color)),
                title: Text(l.name),
                onTap: () => Navigator.pop(ctx, l.id),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (target == null) return;
    await _runBulk(() => ref.read(taskRepoProvider).bulkMoveToList(ids, target));
  }

  Future<void> _bulkSetDate() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final now = DateTime.now();
    final today = DateUtilsEx.formatDate(now);
    final tomorrow = DateUtilsEx.formatDate(now.add(const Duration(days: 1)));
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('今天'), onTap: () => Navigator.pop(ctx, today)),
            ListTile(
                title: const Text('明天'),
                onTap: () => Navigator.pop(ctx, tomorrow)),
            ListTile(
              title: const Text('选择日期…'),
              onTap: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: now,
                  firstDate: DateTime(now.year - 1),
                  lastDate: DateTime(now.year + 5),
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx, d == null ? '__cancel__' : DateUtilsEx.formatDate(d));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || picked == '__cancel__') return;
    await _runBulk(() => ref.read(taskRepoProvider).bulkSetDueDate(ids, picked));
  }

  @override
  Widget build(BuildContext context) {
    final allLists =
        widget.lists ?? ref.watch(listsProvider).valueOrNull ?? const [];
    final tasks = widget.tasks;

    ListModel? listOf(int id) {
      for (final l in allLists) {
        if (l.id == id) return l;
      }
      return null;
    }

    final open = tasks.where((t) => !t.completed).toList()
      ..sort((a, b) {
        final p = b.priority.value.compareTo(a.priority.value);
        if (p != 0) return p;
        return (a.dueDate ?? '9999').compareTo(b.dueDate ?? '9999');
      });
    final done = tasks.where((t) => t.completed).toList();

    Widget buildTile(Task t) {
      return TaskTile(
        task: t,
        list: listOf(t.listId),
        now: widget.now,
        selectMode: _selecting,
        selected: _selectedIds.contains(t.id),
        onLongPress: () => _toggleSelect(t.id!),
        onToggleSelect: () => _toggleSelect(t.id!),
        onTap: _selecting
            ? () => _toggleSelect(t.id!)
            : (widget.onTapTask == null ? null : () => widget.onTapTask!(t)),
        onToggle: () => toggleTaskWithRepeat(ref, t),
        onDelete: () async {
          await ref.read(taskRepoProvider).softDeleteTask(t.id!);
          bumpMutation(ref);
        },
      );
    }

    if (tasks.isEmpty) {
      return EmptyState(
          icon: widget.emptyIcon,
          title: widget.emptyTitle,
          subtitle: widget.emptySubtitle);
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              ...open.map(buildTile),
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
              if (done.isNotEmpty && widget.showCompleted) ...done.map(buildTile),
            ],
          ),
        ),
        if (_selecting)
          _MultiSelectBar(
            count: _selectedIds.length,
            onSelectAll: () =>
                setState(() => _selectedIds.addAll(open.map((t) => t.id!))),
            onMove: _bulkMove,
            onSetDate: _bulkSetDate,
            onDelete: _bulkDelete,
            onCancel: () => setState(_selectedIds.clear),
          ),
      ],
    );
  }
}

/// 多选模式底部操作栏。
class _MultiSelectBar extends StatelessWidget {
  const _MultiSelectBar({
    required this.count,
    required this.onSelectAll,
    required this.onMove,
    required this.onSetDate,
    required this.onDelete,
    required this.onCancel,
  });

  final int count;
  final VoidCallback onSelectAll;
  final VoidCallback onMove;
  final VoidCallback onSetDate;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          border:
              Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
                tooltip: '全选', icon: const Icon(Icons.select_all), onPressed: onSelectAll),
            IconButton(
                tooltip: '移动到清单',
                icon: const Icon(Icons.drive_file_move_outline),
                onPressed: onMove),
            IconButton(
                tooltip: '设置日期', icon: const Icon(Icons.event), onPressed: onSetDate),
            IconButton(
                tooltip: '删除',
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete),
            IconButton(
                tooltip: '取消多选', icon: const Icon(Icons.close), onPressed: onCancel),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('$count',
                  style: Theme.of(context).textTheme.labelLarge),
            ),
          ],
        ),
      ),
    );
  }
}
