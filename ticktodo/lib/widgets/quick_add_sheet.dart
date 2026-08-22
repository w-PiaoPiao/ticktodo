import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/core/quick_add_parser.dart';
import 'package:ticktodo/data/models/list_model.dart';
import 'package:ticktodo/data/models/tag.dart';
import 'package:ticktodo/data/models/task.dart';

/// 弹出底部快速添加输入条。
void showQuickAdd(BuildContext context, {bool defaultDueDate = false}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => QuickAddSheet(defaultDueDate: defaultDueDate),
  );
}

/// 底部快速添加：输入自然语言，实时预览解析结果（日期/时间/优先级/标签）。
class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({super.key, this.defaultDueDate = false});

  /// true 时无日期解析结果默认设为今天（今天视图入口）。
  final bool defaultDueDate;

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _controller = TextEditingController();
  ParsedDraft _draft = ParsedDraft(title: '');
  List<ListModel> _lists = [];
  int? _listId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final meta = ref.read(metaRepoProvider);
    final lists = await meta.queryLists();
    final defaultId = await meta.ensureDefaultList();
    if (!mounted) return;
    setState(() {
      _lists = lists;
      _listId =
          lists.any((l) => l.id == defaultId) ? defaultId : (lists.firstOrNull?.id ?? defaultId);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft.title.isEmpty || _listId == null || _saving) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(taskRepoProvider);
      final meta = ref.read(metaRepoProvider);

      final dueDate = draft.dueDate ??
          (widget.defaultDueDate ? DateUtilsEx.formatDate(DateTime.now()) : null);
      final id = await repo.upsertTask(Task(
        title: draft.title,
        priority: draft.priority,
        dueDate: dueDate,
        dueTime: draft.dueTime,
        listId: _listId!,
      ));

      // 标签：按名查找，不存在则创建
      if (id != null && draft.tagNames.isNotEmpty) {
        final existing = await meta.queryTags();
        for (final name in draft.tagNames) {
          Tag? tag;
          for (final t in existing) {
            if (t.name == name) tag = t;
          }
          final tagId = await meta.upsertTag(tag ?? Tag(name: name));
          if (tagId != null) await meta.linkTaskTag(id, tagId);
        }
      }

      bumpMutation(ref);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
        content: Text('已添加「${draft.title}」'),
        duration: const Duration(seconds: 2),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 2,
            minLines: 1,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: const InputDecoration(
              hintText: '输入任务，如“明天下午3点开会 #工作 !高”',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _draft = QuickAddParser.parse(v)),
          ),
          if (_draft.dueDate != null ||
              _draft.dueTime != null ||
              _draft.priority != TaskPriority.none ||
              _draft.tagNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (_draft.dueDate != null)
                    Chip(
                      avatar: const Icon(Icons.event, size: 16),
                      label: Text(dateBadge(_draft.dueDate!)),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (_draft.dueTime != null)
                    Chip(
                      avatar: const Icon(Icons.schedule, size: 16),
                      label: Text(_draft.dueTime!),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (_draft.priority != TaskPriority.none)
                    Chip(
                      avatar: Icon(Icons.flag,
                          size: 16, color: Color(_draft.priority.colorValue)),
                      label: Text(_draft.priority.label),
                      visualDensity: VisualDensity.compact,
                    ),
                  for (final name in _draft.tagNames)
                    Chip(
                      avatar: const Icon(Icons.label, size: 16),
                      label: Text('#$name'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _listId,
                  decoration: const InputDecoration(
                    labelText: '清单',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final l in _lists)
                      DropdownMenuItem(value: l.id, child: Text(l.name)),
                  ],
                  onChanged: (v) => setState(() => _listId = v),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _draft.title.isEmpty ? null : _save,
                icon: const Icon(Icons.send, size: 18),
                label: const Text('添加'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
