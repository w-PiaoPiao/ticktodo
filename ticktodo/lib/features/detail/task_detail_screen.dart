import 'dart:async';

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

  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  // 防抖窗口内尚未落库的最新编辑
  Task? _pendingSave;
  Timer? _saveDebounce;
  // 最近一次已落库状态（主提醒变更检测的基准）
  Task? _lastSaved;
  // 保存串行化队列：后到的编辑永远后落库，避免并发写乱序回退
  Future<void> _saveQueue = Future.value();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _noteController = TextEditingController();
    _init();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    // 防抖窗口内还有未落库的编辑 → 退出前补写
    final pending = _pendingSave;
    final repo = ref.read(taskRepoProvider);
    if (pending != null && pending.id != null) {
      _saveQueue = _saveQueue.then((_) => repo.upsertTask(pending));
    }
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
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
      _titleController.text = task.title;
      _noteController.text = task.note;
      setState(() {
        _task = task;
        _lastSaved = task;
        _loaded = true;
      });
    } else {
      final task = await repo.getTask(widget.taskId);
      final tagIds = await meta.tagIdsOfTask(widget.taskId);
      if (task != null) {
        _titleController.text = task.title;
        _noteController.text = task.note;
      }
      setState(() {
        _task = task;
        _lastSaved = task;
        _tagIds = tagIds;
        _loaded = true;
      });
    }
  }

  static const _saveDebounceDuration = Duration(milliseconds: 500);

  /// 文本框输入：只更新内存态并防抖落库，不逐键写库。
  void _textChanged() {
    final current = _task;
    if (current == null) return;
    final updated = current.copyWith(
        title: _titleController.text, note: _noteController.text);
    _pendingSave = updated;
    setState(() => _task = updated);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(_saveDebounceDuration, _flushSave);
  }

  /// 结构化编辑（日期/优先级/重复等）：立即落库，并合并文本框中尚未保存的输入。
  Future<void> _save(Task updated) async {
    if (updated.id == null) return;
    updated =
        updated.copyWith(title: _titleController.text, note: _noteController.text);
    _saveDebounce?.cancel();
    _pendingSave = null;
    if (mounted) setState(() => _task = updated);
    await _enqueueSave(updated);
    if (!mounted) return;
    bumpMutation(ref);
  }

  Future<void> _flushSave() async {
    final updated = _pendingSave;
    if (updated == null) return;
    _pendingSave = null;
    await _enqueueSave(updated);
    if (!mounted) return;
    bumpMutation(ref);
  }

  Future<void> _enqueueSave(Task updated) {
    final repo = ref.read(taskRepoProvider);
    final notifications = ref.read(notificationServiceProvider);
    _saveQueue = _saveQueue.then((_) async {
      final remindChanged = updated.remindAt != _lastSaved?.remindAt;
      await repo.upsertTask(updated);
      if (remindChanged) {
        await notifications.cancelReminder(updated.id!);
        if (updated.remindAt != null && !updated.completed) {
          await notifications.scheduleReminder(updated);
        }
      }
      _lastSaved = updated;
    });
    return _saveQueue;
  }

  /// 月重复以设置时的到期日为锚（BYMONTHDAY）：月末钳制不再漂移
  /// （1/31 → 2/28 → 3/31，而非 3/28）。非月重复/无锚需求原样返回。
  String _withMonthAnchor(String encoded) {
    final rule = RepeatRule.parse(encoded);
    final due = _task?.dueDate;
    if (rule == null ||
        due == null ||
        rule.freq != RepeatFreq.monthly ||
        rule.monthDay != null) {
      return encoded;
    }
    final anchored = RepeatRule(
      freq: rule.freq,
      interval: rule.interval,
      byWeekdays: rule.byWeekdays,
      monthDay: DateUtilsEx.parseDate(due).day,
    );
    return anchored.encode();
  }

  /// 额外提醒增删后同步通知系统：先清本任务全部槽位，再按库内当前状态重排。
  Future<void> _rescheduleTaskNotifications() async {
    final task = _task;
    if (task == null) return;
    final taskId = task.id;
    if (taskId == null) return;
    await _flushSave(); // 标题等可能刚改过，通知文案用最新值
    final repo = ref.read(taskRepoProvider);
    final notifications = ref.read(notificationServiceProvider);
    await notifications.cancelReminder(taskId);
    if (task.completed) return;
    if (task.remindAt != null) {
      await notifications.scheduleReminder(task);
    }
    final extras = await repo.queryRemindersOf(taskId);
    if (extras.isNotEmpty) {
      await notifications.scheduleExtraReminders(
        taskId: task.id!,
        title: task.title,
        note: task.note,
        epochs: extras.map((e) => e.remindAt).toList(),
      );
    }
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
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final task = _task;
    if (task == null) {
      // 任务已被删除/传入错误 id：给出提示而非永久转圈
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context).taskDetailTitle)),
        body: Center(
            child: Text(AppLocalizations.of(context).taskNotFound)),
      );
    }
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
            controller: _titleController,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l10n.taskTitleHint,
              border: InputBorder.none,
            ),
            onChanged: (_) => _textChanged(),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _noteController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: l10n.taskNoteHint,
              border: InputBorder.none,
            ),
            onChanged: (_) => _textChanged(),
          ),
          const Divider(height: 24),
          DateTimeSection(task: task, onChanged: _save),
          const Divider(height: 24),
          RemindersSection(task: task, onChanged: () async {
            // 额外提醒增删要联动通知系统（旧通知照响/新通知不响的修复）
            await _rescheduleTaskNotifications();
            if (!mounted) return;
            bumpMutation(ref);
          }),
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
                  : task.copyWith(repeatRule: _withMonthAnchor(encoded)));
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
