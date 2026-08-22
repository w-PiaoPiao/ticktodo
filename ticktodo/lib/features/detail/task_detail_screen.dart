import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/core/repeat_rule.dart';
import 'package:ticktodo/data/models/subtask.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/features/detail/subtask_section.dart';
import 'package:ticktodo/features/detail/tag_section.dart';
import 'package:ticktodo/notifications/notification_service.dart';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定要删除「${task.title.isEmpty ? '无标题任务' : task.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Color(AppColors.overDueRed))),
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

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _task == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final task = _task!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务详情'),
        actions: [
          IconButton(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除',
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
            decoration: const InputDecoration(
              hintText: '任务标题',
              border: InputBorder.none,
            ),
            onChanged: (v) => _save(task.copyWith(title: v)),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: task.note),
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '备注',
              border: InputBorder.none,
            ),
            onChanged: (v) => _save(task.copyWith(note: v)),
          ),
          const Divider(height: 24),
          DateTimeSection(task: task, onChanged: _save),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.repeat, size: 20),
            title: Text(task.repeatRule == null
                ? '重复'
                : '重复 · ${RepeatRule.parse(task.repeatRule)?.label ?? '自定义'}'),
            trailing: task.repeatRule == null
                ? const Icon(Icons.chevron_right)
                : IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: '清除重复',
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
              title: const Text('优先级'),
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
    );
  }
}
