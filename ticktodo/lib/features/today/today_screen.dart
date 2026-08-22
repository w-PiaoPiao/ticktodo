import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/features/detail/task_detail_screen.dart';
import 'package:ticktodo/features/search/search_screen.dart';
import 'package:ticktodo/features/shared/task_list_view.dart';
import 'package:ticktodo/widgets/quick_add_sheet.dart';

/// 今天视图
final todayTasksProvider = FutureProvider<List<Task>>((ref) async {
  ref.watch(taskMutationProvider);
  final now = DateTime.now();
  return ref
      .read(taskRepoProvider)
      .queryToday(today: DateUtilsEx.formatDate(now));
});

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(todayTasksProvider).valueOrNull ?? const [];
    final now = DateTime.now();
    final weekday = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][now.weekday - 1];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('今天',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(
              '${DateFormat('M月d日').format(now)} $weekday',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-today',
        onPressed: () => showQuickAdd(context, defaultDueDate: true),
        child: const Icon(Icons.add),
      ),
      body: TaskListView(
        tasks: tasks,
        emptyIcon: Icons.today,
        emptyTitle: '今天没有任务',
        emptySubtitle: '点击右下角 + 快速添加',
        onTapTask: (t) => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TaskDetailScreen(taskId: t.id ?? 0),
        )),
      ),
    );
  }
}
