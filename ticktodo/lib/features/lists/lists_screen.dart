import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/list_model.dart';
import 'package:ticktodo/data/repositories/meta_repository.dart';
import 'package:ticktodo/data/repositories/task_repository.dart';

/// 清单管理页；pickMode=true 时点击返回所选清单
class ListsScreen extends ConsumerStatefulWidget {
  const ListsScreen({super.key, this.pickMode = false});

  final bool pickMode;

  @override
  ConsumerState<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends ConsumerState<ListsScreen> {
  final _nameCtrl = TextEditingController();
  int _color = kPalette.first;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _createList() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final meta = ref.read(metaRepoProvider);
    await meta.upsertList(ListModel(name: name, color: _color));
    _nameCtrl.clear();
    bumpMutation(ref);
  }

  /// 拖拽排序：按新顺序批量写回 sortOrder
  Future<void> _reorder(int oldIndex, int newIndex) async {
    final lists =
        (ref.read(listsProvider).valueOrNull ?? const <ListModel>[]).toList();
    if (oldIndex < 0 || oldIndex >= lists.length) return;
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final moved = lists.removeAt(oldIndex);
      lists.insert(newIndex.clamp(0, lists.length), moved);
    });
    final meta = ref.read(metaRepoProvider);
    for (var i = 0; i < lists.length; i++) {
      await meta.upsertList(lists[i].copyWith(sortOrder: i));
    }
    bumpMutation(ref);
  }

  Future<void> _togglePin(ListModel list) async {
    final meta = ref.read(metaRepoProvider);
    await meta.upsertList(list.copyWith(isPinned: !list.isPinned));
    bumpMutation(ref);
  }

  Future<void> _deleteList(ListModel list) async {
    if (list.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('默认清单「收集箱」不可删除')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除清单'),
        content: Text('删除「${list.name}」？其中的任务将保留（回到默认清单）。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Color(AppColors.overDueRed))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final meta = ref.read(metaRepoProvider);
    final taskRepo = ref.read(taskRepoProvider);
    final defaultListId = await meta.ensureDefaultList();
    final tasks = await taskRepo.queryByList(list.id!);
    for (final t in tasks) {
      await taskRepo.upsertTask(t.copyWith(listId: defaultListId));
    }
    await meta.softDeleteList(list.id!);
    bumpMutation(ref);
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(listsProvider).valueOrNull ?? const <ListModel>[];
    final taskRepo = ref.read(taskRepoProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pickMode ? '选择清单' : '清单'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              itemCount: lists.length,
              onReorder: _reorder,
              buildDefaultDragHandles: !widget.pickMode,
              itemBuilder: (ctx, i) {
                final list = lists[i];
                return ListTile(
                  key: ValueKey('list-${list.id}'),
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color(list.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Row(
                    children: [
                      if (list.isPinned) ...[
                        Icon(Icons.push_pin, size: 13, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                      ],
                      Expanded(child: Text(list.name)),
                    ],
                  ),
                  subtitle: FutureBuilder<int>(
                    future: taskRepo.queryByList(list.id!).then((t) => t.length),
                    builder: (_, snap) => Text(
                      '${snap.data ?? 0} 个任务',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  trailing: widget.pickMode
                      ? const Icon(Icons.chevron_right)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                list.isPinned
                                    ? Icons.push_pin
                                    : Icons.push_pin_outlined,
                                size: 20,
                                color: list.isPinned
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                              tooltip: list.isPinned ? '取消置顶' : '置顶',
                              onPressed: () => _togglePin(list),
                            ),
                            if (!list.isDefault)
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _deleteList(list),
                              ),
                          ],
                        ),
                  onTap: widget.pickMode
                      ? () => Navigator.pop(context, list)
                      : null,
                );
              },
            ),
          ),
          // 新建清单输入
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('新建清单',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          hintText: '清单名称',
                          isDense: true,
                        ),
                        onSubmitted: (_) => _createList(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _color,
                      items: [
                        for (final c in kPalette)
                          DropdownMenuItem(
                            value: c,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Color(c),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _color = v ?? _color),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.add),
                      onPressed: _createList,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
