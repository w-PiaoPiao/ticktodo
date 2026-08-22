import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/widgets/empty_state.dart';

/// 回收站：软删除任务可恢复或彻底删除。
class TrashScreen extends ConsumerStatefulWidget {
  const TrashScreen({super.key});

  @override
  ConsumerState<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends ConsumerState<TrashScreen> {
  List<Task>? _tasks;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tasks = await ref.read(taskRepoProvider).queryDeleted();
    if (!mounted) return;
    setState(() => _tasks = tasks);
  }

  Future<bool> _confirm(String title, {String? content}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: content == null ? null : Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('彻底删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _restore(Task t) async {
    await ref.read(taskRepoProvider).restoreTask(t.id!);
    bumpMutation(ref);
    _load();
  }

  Future<void> _hardDelete(List<Task> targets) async {
    if (targets.isEmpty) return;
    final single = targets.length == 1;
    final name = single
        ? '「${targets.first.title.isEmpty ? '无标题任务' : targets.first.title}」'
        : '${targets.length} 个任务';
    if (!await _confirm('彻底删除 $name',
        content: '彻底删除后无法恢复，确定吗？')) {
      return;
    }
    await ref
        .read(taskRepoProvider)
        .hardDeleteTasks(targets.map((t) => t.id!).toList());
    bumpMutation(ref);
    _load();
  }

  Future<void> _emptyAll() async {
    final tasks = _tasks;
    if (tasks == null || tasks.isEmpty) return;
    if (!await _confirm('清空回收站',
        content: '将彻底删除全部 ${tasks.length} 个任务，无法恢复。')) {
      return;
    }
    await ref
        .read(taskRepoProvider)
        .hardDeleteTasks(tasks.map((t) => t.id!).toList());
    bumpMutation(ref);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _tasks;
    return Scaffold(
      appBar: AppBar(
        title: const Text('回收站'),
        actions: [
          if (tasks != null && tasks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '清空回收站',
              onPressed: _emptyAll,
            ),
        ],
      ),
      body: tasks == null
          ? const Center(child: CircularProgressIndicator())
          : tasks.isEmpty
              ? const EmptyState(icon: Icons.delete_outline, title: '回收站为空')
              : ListView(
                  children: [
                    for (final t in tasks)
                      ListTile(
                        key: ValueKey('trash-${t.id}'),
                        title: Text(t.title.isEmpty ? '无标题任务' : t.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: t.deletedAt == null
                            ? null
                            : Text(
                                '删除于 ${DateFormat('yyyy年M月d日').format(DateTime.fromMillisecondsSinceEpoch(t.deletedAt!))}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.restore),
                              tooltip: '恢复',
                              onPressed: () => _restore(t),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever_outlined),
                              tooltip: '彻底删除',
                              onPressed: () => _hardDelete([t]),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}
