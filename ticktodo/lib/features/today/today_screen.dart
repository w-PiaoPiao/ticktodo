import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/features/detail/task_detail_screen.dart';
import 'package:ticktodo/features/search/search_screen.dart';
import 'package:ticktodo/features/shared/task_list_view.dart';
import 'package:ticktodo/l10n/app_localizations.dart';
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
  const TodayScreen({super.key, this.desktopMode = false});

  /// 桌面布局：隐藏移动端 FAB（新建走 Cmd+N / 侧边栏按钮）
  final bool desktopMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tasks = ref.watch(todayTasksProvider).valueOrNull ?? const [];
    final now = DateTime.now();
    final weekday = (l10n.localeName.startsWith('zh')
        ? ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])[now.weekday - 1];
    final dateFmt =
        l10n.localeName.startsWith('zh') ? DateFormat('M月d日') : DateFormat('MMM d');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.navToday,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(
              '${dateFmt.format(now)} $weekday',
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
            tooltip: l10n.navSearch,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: desktopMode
          ? null
          : FloatingActionButton(
              heroTag: 'fab-today',
              onPressed: () => showQuickAdd(context, defaultDueDate: true),
              child: const Icon(Icons.add),
            ),
      body: TaskListView(
        tasks: tasks,
        emptyIcon: Icons.today,
        emptyTitle: l10n.todayEmptyTitle,
        emptySubtitle: l10n.todayEmptySubtitle,
        onTapTask: (t) => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TaskDetailScreen(taskId: t.id ?? 0),
        )),
      ),
    );
  }
}
