import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/subtask.dart';
import 'package:ticktodo/l10n/app_localizations.dart';

class SubtaskSection extends ConsumerStatefulWidget {
  const SubtaskSection({super.key, required this.taskId});

  final int taskId;

  @override
  ConsumerState<SubtaskSection> createState() => _SubtaskSectionState();
}

class _SubtaskSectionState extends ConsumerState<SubtaskSection> {
  List<Subtask> _subtasks = [];
  final _inputCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final subs = await ref.read(taskRepoProvider).subtasksOf(widget.taskId);
    if (mounted) setState(() => _subtasks = subs);
  }

  Future<void> _add() async {
    final title = _inputCtrl.text.trim();
    if (title.isEmpty) return;
    final repo = ref.read(taskRepoProvider);
    await repo.upsertSubtask(Subtask(
      taskId: widget.taskId,
      title: title,
      sortOrder: _subtasks.length,
    ));
    _inputCtrl.clear();
    bumpMutation(ref);
    await _load();
  }

  Future<void> _toggle(Subtask s) async {
    await ref.read(taskRepoProvider).toggleSubtask(s.id!, !s.completed);
    bumpMutation(ref);
    await _load();
  }

  Future<void> _delete(Subtask s) async {
    await ref.read(taskRepoProvider).softDeleteSubtask(s.id!);
    bumpMutation(ref);
    await _load();
  }

  Future<void> _move(Subtask s, int delta) async {
    final repo = ref.read(taskRepoProvider);
    final index = _subtasks.indexWhere((e) => e.id == s.id);
    final target = index + delta;
    if (target < 0 || target >= _subtasks.length) return;
    final list = [..._subtasks];
    list.removeAt(index);
    list.insert(target, s);
    for (var i = 0; i < list.length; i++) {
      await repo.upsertSubtask(list[i].copyWith(sortOrder: i));
    }
    bumpMutation(ref);
    await _load();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(l10n.taskSubtaskTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ),
        for (final s in _subtasks)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Checkbox(
              value: s.completed,
              onChanged: (_) => _toggle(s),
            ),
            title: Text(
              s.title,
              style: s.completed
                  ? TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Theme.of(context).colorScheme.outline,
                    )
                  : null,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: () => _move(s, -1),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: () => _move(s, 1),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _delete(s),
                ),
              ],
            ),
          ),
        TextField(
          controller: _inputCtrl,
          decoration: InputDecoration(
            hintText: l10n.taskSubtaskHint,
            prefixIcon: const Icon(Icons.add, size: 20),
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _add(),
        ),
      ],
    );
  }
}
