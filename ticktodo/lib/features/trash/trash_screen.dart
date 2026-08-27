import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: content == null ? null : Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.trashPurgeTitle,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// 删除时间的本地化格式。
  String _formatDeletedAt(int ms, AppLocalizations l10n) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final fmt = l10n.localeName.startsWith('zh')
        ? DateFormat('yyyy年M月d日')
        : DateFormat('MMM d, yyyy');
    return fmt.format(dt);
  }

  Future<void> _restore(Task t) async {
    await ref.read(taskRepoProvider).restoreTask(t.id!);
    bumpMutation(ref);
    _load();
  }

  Future<void> _hardDelete(List<Task> targets) async {
    if (targets.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final single = targets.length == 1;
    final name = single
        ? '「${targets.first.title.isEmpty ? l10n.untitledTask : targets.first.title}」'
        : l10n.trashCountTasks(targets.length);
    if (!await _confirm('${l10n.trashPurgeTitle} $name',
        content: l10n.trashPurgeConfirm)) {
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
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.trashClearTitle,
        content: l10n.trashClearConfirm(tasks.length))) {
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
    final l10n = AppLocalizations.of(context);
    final tasks = _tasks;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trashTitle),
        actions: [
          if (tasks != null && tasks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: l10n.trashClearTooltip,
              onPressed: _emptyAll,
            ),
        ],
      ),
      body: tasks == null
          ? const Center(child: CircularProgressIndicator())
          : tasks.isEmpty
              ? EmptyState(icon: Icons.delete_outline, title: l10n.trashEmpty)
              : ListView(
                  children: [
                    for (final t in tasks)
                      ListTile(
                        key: ValueKey('trash-${t.id}'),
                        title: Text(t.title.isEmpty ? l10n.untitledTask : t.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: t.deletedAt == null
                            ? null
                            : Text(
                                l10n.trashDeletedAt(_formatDeletedAt(
                                    t.deletedAt!, l10n)),
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
                              tooltip: l10n.trashRestoreTooltip,
                              onPressed: () => _restore(t),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever_outlined),
                              tooltip: l10n.trashPurgeTooltip,
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
