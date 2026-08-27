import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/features/all/all_screen.dart'
    show allTasksProvider;
import 'package:ticktodo/features/detail/task_detail_screen.dart';
import 'package:ticktodo/l10n/app_localizations.dart';

/// 四象限视图（艾森豪威尔矩阵）：
/// 纵轴「重要性」= 优先级中/高；横轴「紧急性」= 到期日为今天或已过期。
class MatrixScreen extends ConsumerWidget {
  const MatrixScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
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
      appBar: AppBar(title: Text(l10n.navMatrix)),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _quadrant(context,
                    title: l10n.matrixQ1Title, subtitle: l10n.matrixQ1Subtitle, tasks: q1, color: AppColors.overDueRed),
                _quadrant(context,
                    title: l10n.matrixQ2Title, subtitle: l10n.matrixQ2Subtitle, tasks: q2, color: 0xFF2F9D45),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _quadrant(context,
                    title: l10n.matrixQ3Title, subtitle: l10n.matrixQ3Subtitle, tasks: q3, color: 0xFFF29900),
                _quadrant(context,
                    title: l10n.matrixQ4Title, subtitle: l10n.matrixQ4Subtitle, tasks: q4, color: 0xFF9E9E9E),
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
    final l10n = AppLocalizations.of(context);
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
                      child: Text(l10n.matrixEmpty,
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
                            t.title.isEmpty ? l10n.untitledTask : t.title,
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
