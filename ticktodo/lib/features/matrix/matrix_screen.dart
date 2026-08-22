import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/features/all/all_screen.dart'
    show allTasksProvider;
import 'package:ticktodo/features/detail/task_detail_screen.dart';

/// 四象限视图（艾森豪威尔矩阵）：
/// 纵轴「重要性」= 优先级中/高；横轴「紧急性」= 到期日为今天或已过期。
class MatrixScreen extends ConsumerWidget {
  const MatrixScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(allTasksProvider).valueOrNull ?? const [];
    final open = tasks.where((t) => !t.completed).toList();

    final now = DateTime.now();
    bool isUrgent(Task t) =>
        t.dueDate != null &&
        (DateUtilsEx.parseDate(t.dueDate!)
            .isBefore(DateTime(now.year, now.month, now.day + 1)));
    bool isImportant(Task t) => t.priority.value >= TaskPriority.medium.value;

    final q1 = open.where((t) => isImportant(t) && isUrgent(t)).toList()
      ..sort(_byDueThenPriority);
    final q2 = open.where((t) => isImportant(t) && !isUrgent(t)).toList()
      ..sort(_byDueThenPriority);
    final q3 = open.where((t) => !isImportant(t) && isUrgent(t)).toList()
      ..sort(_byDueThenPriority);
    final q4 = open.where((t) => !isImportant(t) && !isUrgent(t)).toList()
      ..sort(_byDueThenPriority);

    return Scaffold(
      appBar: AppBar(title: const Text('四象限')),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _quadrant(context,
                    title: '重要且紧急', subtitle: '立即做', tasks: q1, color: AppColors.overDueRed),
                _quadrant(context,
                    title: '重要不紧急', subtitle: '安排做', tasks: q2, color: 0xFF2F9D45),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _quadrant(context,
                    title: '紧急不重要', subtitle: '委托做', tasks: q3, color: 0xFFF29900),
                _quadrant(context,
                    title: '不重要不紧急', subtitle: '少做', tasks: q4, color: 0xFF9E9E9E),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _byDueThenPriority(Task a, Task b) {
    final d = (a.dueDate ?? '9999').compareTo(b.dueDate ?? '9999');
    if (d != 0) return d;
    return b.priority.value.compareTo(a.priority.value);
  }

  Widget _quadrant(
    BuildContext context, {
    required String title,
    required String subtitle,
    required List<Task> tasks,
    required int color,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        margin: const EdgeInsets.all(6),
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: Color(color), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('$title · $subtitle',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  Text('${tasks.length}',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Text('空',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: tasks.length,
                      itemBuilder: (_, i) {
                        final t = tasks[i];
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          leading: Icon(Icons.radio_button_unchecked,
                              size: 18, color: Color(t.priority.colorValue)),
                          title: Text(
                            t.title.isEmpty ? '无标题任务' : t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    TaskDetailScreen(taskId: t.id ?? 0)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
