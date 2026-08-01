import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/features/detail/task_detail_screen.dart';
import 'package:ticktodo/features/shared/task_list_view.dart';

/// 最近7天视图
final weekTasksProvider = FutureProvider<List<Task>>((ref) async {
  ref.watch(taskMutationProvider);
  final now = DateTime.now();
  final start = DateUtilsEx.formatDate(now);
  final end = DateUtilsEx.formatDate(now.add(const Duration(days: 6)));
  return ref.read(taskRepoProvider).queryWeek(start: start, end: end);
});

class WeekScreen extends ConsumerWidget {
  const WeekScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(weekTasksProvider).valueOrNull ?? const [];
    final remaining = tasks.where((t) => !t.completed).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('最近7天',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(
              remaining == 0 ? '全部完成' : '还有 $remaining 项待完成',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-week',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const TaskDetailScreen(taskId: 0),
        )),
        child: const Icon(Icons.add),
      ),
      body: TaskListView(
        tasks: tasks,
        emptyIcon: Icons.date_range,
        emptyTitle: '未来7天没有任务',
        emptySubtitle: '点右下角 + 添加带日期的任务',
        onTapTask: (t) => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TaskDetailScreen(taskId: t.id ?? 0),
        )),
      ),
    );
  }
}
