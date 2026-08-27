import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/core/repeat_rule.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/features/detail/reminders_section.dart';
import 'package:ticktodo/features/detail/subtask_section.dart';
import 'package:ticktodo/features/detail/tag_section.dart';
import 'package:ticktodo/l10n/app_localizations.dart';
import 'package:ticktodo/widgets/date_time_picker.dart';
import 'package:ticktodo/widgets/priority_picker.dart';
import 'package:ticktodo/widgets/repeat_picker.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({
    super.key,
    required this.taskId,
    this.defaultDueDate = false,
  });

  /// 0 = 新建
  final int taskId;
  final bool defaultDueDate;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  Task? _task;
  List<int> _tagIds = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final repo = ref.read(taskRepoProvider);
    final meta = ref.read(metaRepoProvider);
    if (widget.taskId == 0) {
      final defaultListId = await meta.ensureDefaultList();
      var task = Task(
        title: '',
        listId: defaultListId,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      if (widget.defaultDueDate) {
        task = task.copyWith(dueDate: DateUtilsEx.formatDate(DateTime.now()));
      }
      final id = await repo.upsertTask(task);
      task = (await repo.getTask(id!))!;
      setState(() {
        _task = task;
        _loaded = true;
      });
    } else {
      final task = await repo.getTask(widget.taskId);
      final tagIds = await meta.tagIdsOfTask(widget.taskId);
      setState(() {
        _task = task;
        _tagIds = tagIds;
        _loaded = true;
      });
    }
  }

  Future<void> _save(Task updated) async {
    if (updated.id == null) return;
    final repo = ref.read(taskRepoProvider);
    final notifications = ref.read(notificationServiceProvider);

    // 提醒变化 → 重调度通知
    final remindChanged =
        updated.remindAt != _task?.remindAt;
    await repo.upsertTask(updated);
    if (remindChanged) {
      await notifications.cancelReminder(updated.id!);
      if (updated.remindAt != null && !updated.completed) {
        await notifications.scheduleReminder(updated);
      }
    }
    setState(() => _task = updated);
    bumpMutation(ref);
  }

  Future<void> _delete() async {
    final task = _task;
    if (task == null || task.id == null) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.taskDeleteTitle),
        content: Text(l10n.taskDeleteConfirm(
            task.title.isEmpty ? l10n.untitledTask : task.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonDelete,
                style: const TextStyle(color: Color(AppColors.overDueRed))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ref.read(taskRepoProvider);
    final notifications = ref.read(notificationServiceProvider);
    await notifications.cancelReminder(task.id!);
    await repo.softDeleteTask(task.id!);
    bumpMutation(ref);
    if (mounted) Navigator.of(context).pop();
  }

  /// 新建页未填写任何内容就退出 → 丢弃空任务（软删除进回收站）
  bool get _isEmptyNew =>
      widget.taskId == 0 &&
      (_task == null ||
          (_task!.title.trim().isEmpty && _task!.note.trim().isEmpty));

  Future<void> _discardAndPop() async {
    final t = _task;
    if (t?.id != null) {
      await ref.read(notificationServiceProvider).cancelReminder(t!.id!);
      await ref.read(taskRepoProvider).softDeleteTask(t.id!);
      bumpMutation(ref);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _task == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final task = _task!;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: !_isEmptyNew,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _discardAndPop();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(l10n.taskDetailTitle),
        actions: [
          IconButton(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.taskDeleteTooltip,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          TextField(
            controller: TextEditingController(text: task.title),
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l10n.taskTitleHint,
              border: InputBorder.none,
            ),
            onChanged: (v) => _save(task.copyWith(title: v)),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: task.note),
            maxLines: 5,
            decoration: InputDecoration(
              hintText: l10n.taskNoteHint,
              border: InputBorder.none,
            ),
            onChanged: (v) => _save(task.copyWith(note: v)),
          ),
          const Divider(height: 24),
          DateTimeSection(task: task, onChanged: _save),
          const Divider(height: 24),
          RemindersSection(task: task, onChanged: () => bumpMutation(ref)),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.repeat, size: 20),
            title: Text(task.repeatRule == null
                ? l10n.repeatTitle
                : l10n.taskRepeatPrefix(
                    RepeatRule.parse(task.repeatRule)?.label(l10n) ??
                        l10n.commonCustom)),
            trailing: task.repeatRule == null
                ? const Icon(Icons.chevron_right)
                : IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.taskRepeatClear,
                    onPressed: () => _save(task.copyWith(clearRepeatRule: true)),
                  ),
            onTap: () async {
              final encoded =
                  await showRepeatPicker(context, currentEncoded: task.repeatRule);
              if (!mounted || encoded == null) return; // 取消/点外部关闭
              _save(encoded.isEmpty
                  ? task.copyWith(clearRepeatRule: true)
                  : task.copyWith(repeatRule: encoded));
            },
          ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined, size: 20),
              title: Text(l10n.taskPriority),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: PriorityPicker(
              value: task.priority,
              onChanged: (p) => _save(task.copyWith(priority: p)),
            ),
          ),
          const Divider(height: 24),
          TagSection(task: task, selectedTagIds: _tagIds, onChanged: (ids) {
            setState(() => _tagIds = ids);
            _save(task);
          }),
          const Divider(height: 24),
          SubtaskSection(taskId: task.id!),
          const SizedBox(height: 40),
        ],
      ),
      ),
    );
  }
}
