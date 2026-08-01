import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/features/detail/task_detail_screen.dart';
import 'package:ticktodo/features/shared/task_list_view.dart';

/// 全部任务：未完成在前，按清单分组？——统一列表 + 筛选 chips
final allTasksProvider = FutureProvider<List<Task>>((ref) async {
  ref.watch(taskMutationProvider);
  return ref.read(taskRepoProvider).queryAll();
});

class AllScreen extends ConsumerStatefulWidget {
  const AllScreen({super.key});

  @override
  ConsumerState<AllScreen> createState() => _AllScreenState();
}

class _AllScreenState extends ConsumerState<AllScreen> {
  int? _filterListId;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(allTasksProvider).valueOrNull ?? const [];
    final lists = ref.watch(listsProvider).valueOrNull ?? const [];
    final filtered = _filterListId == null
        ? tasks
        : tasks.where((t) => t.listId == _filterListId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('全部任务',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => showModalBottomSheet<int>(
              context: context,
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('全部清单'),
                      trailing: _filterListId == null
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () {
                        setState(() => _filterListId = null);
                        Navigator.pop(ctx);
                      },
                    ),
                    for (final l in lists)
                      ListTile(
                        leading: Icon(Icons.circle,
                            size: 10, color: Color(l.color)),
                        title: Text(l.name),
                        trailing: _filterListId == l.id
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () {
                          setState(() => _filterListId = l.id);
                          Navigator.pop(ctx);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-all',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const TaskDetailScreen(taskId: 0),
        )),
        child: const Icon(Icons.add),
      ),
      body: TaskListView(
        tasks: filtered,
        emptyIcon: Icons.checklist,
        emptyTitle: _filterListId == null ? '还没有任务' : '该清单暂无任务',
        emptySubtitle: '点击右下角 + 添加任务',
        onTapTask: (t) => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TaskDetailScreen(taskId: t.id ?? 0),
        )),
      ),
    );
  }
}
