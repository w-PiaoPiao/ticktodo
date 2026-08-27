import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/list_model.dart';
import 'package:ticktodo/data/models/tag.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/features/lists/lists_screen.dart';
import 'package:ticktodo/features/tags/tags_screen.dart';
import 'package:ticktodo/l10n/app_localizations.dart';

/// 详情页：清单选择 + 标签多选
class TagSection extends ConsumerWidget {
  const TagSection({
    super.key,
    required this.task,
    required this.selectedTagIds,
    required this.onChanged,
  });

  final Task task;
  final List<int> selectedTagIds;
  final void Function(List<int>) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lists = ref.watch(listsProvider).valueOrNull ?? const <ListModel>[];
    final tags = ref.watch(tagsProvider).valueOrNull ?? const <Tag>[];
    final meta = ref.read(metaRepoProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 清单
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.playlist_play, size: 20),
          title: Text(l10n.listSection),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Color(
                      lists.firstWhere((l) => l.id == task.listId,
                              orElse: () => const ListModel(name: '', id: null))
                          .color),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                lists.firstWhere((l) => l.id == task.listId,
                        orElse: () => const ListModel(name: ''))
                    .name,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
          onTap: () async {
            final picked = await Navigator.of(context).push<ListModel>(
              MaterialPageRoute(builder: (_) => const ListsScreen(pickMode: true)),
            );
            if (picked != null) {
              onChanged(selectedTagIds);
              await meta.upsertList(picked);
              // 保存清单归属：触发父级保存
              ref.read(taskRepoProvider).upsertTask(task.copyWith(listId: picked.id!));
              bumpMutation(ref);
            }
          },
        ),
        const SizedBox(height: 8),
        // 标签
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...tags.map((tag) {
              final selected = selectedTagIds.contains(tag.id);
              return FilterChip(
                label: Text(tag.name),
                selected: selected,
                avatar: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Color(tag.color),
                    shape: BoxShape.circle,
                  ),
                ),
                onSelected: (sel) async {
                  if (sel) {
                    await meta.linkTaskTag(task.id!, tag.id!);
                    onChanged([...selectedTagIds, tag.id!]);
                  } else {
                    await meta.unlinkTaskTag(task.id!, tag.id!);
                    onChanged(selectedTagIds.where((i) => i != tag.id).toList());
                  }
                  bumpMutation(ref);
                },
              );
            }),
            ActionChip(
              avatar: const Icon(Icons.edit_outlined, size: 16),
              label: Text(l10n.tagManageAction),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TagsScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
