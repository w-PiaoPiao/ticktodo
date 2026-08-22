import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/filter.dart';
import 'package:ticktodo/data/models/list_model.dart';
import 'package:ticktodo/data/models/tag.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/features/detail/task_detail_screen.dart';
import 'package:ticktodo/features/shared/task_list_view.dart';
import 'package:ticktodo/widgets/empty_state.dart';

/// 智能清单（自定义过滤器）管理页。
class FiltersScreen extends ConsumerStatefulWidget {
  const FiltersScreen({super.key});

  @override
  ConsumerState<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends ConsumerState<FiltersScreen> {
  List<Filter>? _filters;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = await ref.read(filterRepoProvider).queryFilters();
    if (!mounted) return;
    setState(() => _filters = f);
  }

  Future<void> _openEditor([Filter? existing]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FilterEditScreen(existing: existing)),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Filter f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除智能清单'),
        content: Text('确定删除「${f.name}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(filterRepoProvider).softDeleteFilter(f.id!);
    bumpMutation(ref);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final filters = _filters;
    return Scaffold(
      appBar: AppBar(title: const Text('智能清单')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-filters',
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
      body: filters == null
          ? const Center(child: CircularProgressIndicator())
          : filters.isEmpty
              ? EmptyState(
                  icon: Icons.filter_alt_outlined,
                  title: '还没有智能清单',
                  subtitle: '按清单/标签/优先级/日期组合创建',
                )
              : ListView(
                  children: [
                    for (final f in filters)
                      ListTile(
                        key: ValueKey('filter-${f.id}'),
                        leading: const Icon(Icons.filter_alt),
                        title: Text(f.name),
                        subtitle: Text(_describe(f),
                            style: Theme.of(context).textTheme.bodySmall),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: '删除',
                          onPressed: () => _delete(f),
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => FilterResultScreen(filter: f)),
                        ),
                      ),
                  ],
                ),
    );
  }

  String _describe(Filter f) {
    final parts = <String>[];
    if (f.listIds.isNotEmpty) parts.add('${f.listIds.length} 个清单');
    if (f.tagIds.isNotEmpty) parts.add('${f.tagIds.length} 个标签');
    if (f.minPriority > 0) {
      parts.add(
          '${switch (f.minPriority) { 3 => '高', 2 => '中以上', _ => '低以上' }}优先级');
    }
    if (f.dateMode != FilterDateMode.any) parts.add(f.dateMode.label);
    return parts.isEmpty ? '全部未完成任务' : parts.join(' · ');
  }
}

// ---------- 编辑页 ----------

class FilterEditScreen extends ConsumerStatefulWidget {
  const FilterEditScreen({super.key, this.existing});

  final Filter? existing;

  @override
  ConsumerState<FilterEditScreen> createState() => _FilterEditScreenState();
}

class _FilterEditScreenState extends ConsumerState<FilterEditScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  List<ListModel> _lists = [];
  List<Tag> _tags = [];
  final Set<int> _listIds = {};
  final Set<int> _tagIds = {};
  late int _minPriority = widget.existing?.minPriority ?? 0;
  late FilterDateMode _dateMode = widget.existing?.dateMode ?? FilterDateMode.any;

  @override
  void initState() {
    super.initState();
    _listIds.addAll(widget.existing?.listIds ?? const []);
    _tagIds.addAll(widget.existing?.tagIds ?? const []);
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final lists = await ref.read(metaRepoProvider).queryLists();
    final tags = await ref.read(metaRepoProvider).queryTags();
    if (!mounted) return;
    setState(() {
      _lists = lists;
      _tags = tags;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    await ref.read(filterRepoProvider).upsertFilter(Filter(
          id: widget.existing?.id,
          name: _name.text.trim(),
          listIds: _listIds.toList(),
          tagIds: _tagIds.toList(),
          minPriority: _minPriority,
          dateMode: _dateMode,
        ));
    bumpMutation(ref);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? '新建智能清单' : '编辑智能清单'),
        actions: [
          IconButton(icon: const Icon(Icons.check), tooltip: '保存', onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '名称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('清单（不选=全部）', style: theme.textTheme.labelMedium),
          Wrap(
            spacing: 6,
            children: [
              for (final l in _lists)
                FilterChip(
                  label: Text(l.name),
                  selected: _listIds.contains(l.id),
                  onSelected: (sel) => setState(
                      () => sel ? _listIds.add(l.id!) : _listIds.remove(l.id)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('标签（不选=不限）', style: theme.textTheme.labelMedium),
          Wrap(
            spacing: 6,
            children: [
              for (final t in _tags)
                FilterChip(
                  label: Text(t.name),
                  selected: _tagIds.contains(t.id),
                  onSelected: (sel) => setState(
                      () => sel ? _tagIds.add(t.id!) : _tagIds.remove(t.id)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('最低优先级', style: theme.textTheme.labelMedium),
          Wrap(
            spacing: 6,
            children: [
              for (final (v, label) in [(0, '不限'), (1, '低以上'), (2, '中以上'), (3, '仅高')])
                ChoiceChip(
                  label: Text(label),
                  selected: _minPriority == v,
                  onSelected: (_) => setState(() => _minPriority = v),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('日期范围', style: theme.textTheme.labelMedium),
          Wrap(
            spacing: 6,
            children: [
              for (final m in FilterDateMode.values)
                ChoiceChip(
                  label: Text(m.label),
                  selected: _dateMode == m,
                  onSelected: (_) => setState(() => _dateMode = m),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------- 结果视图 ----------

/// 展示某过滤器命中的任务列表。
class FilterResultScreen extends ConsumerStatefulWidget {
  const FilterResultScreen({super.key, required this.filter});

  final Filter filter;

  @override
  ConsumerState<FilterResultScreen> createState() => _FilterResultScreenState();
}

class _FilterResultScreenState extends ConsumerState<FilterResultScreen> {
  List<Task>? _tasks;

  @override
  void initState() {
    super.initState();
    ref.listenManual(taskMutationProvider, (_, _) => _load());
    _load();
  }

  Future<void> _load() async {
    final r = await ref.read(filterRepoProvider).queryTasksByFilter(widget.filter);
    if (!mounted) return;
    setState(() => _tasks = r);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _tasks;
    return Scaffold(
      appBar: AppBar(title: Text(widget.filter.name)),
      body: tasks == null
          ? const Center(child: CircularProgressIndicator())
          : TaskListView(
              tasks: tasks,
              emptyIcon: Icons.filter_alt_outlined,
              emptyTitle: '没有符合条件的任务',
              onTapTask: (t) => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => TaskDetailScreen(taskId: t.id ?? 0)),
              ),
            ),
    );
  }
}
