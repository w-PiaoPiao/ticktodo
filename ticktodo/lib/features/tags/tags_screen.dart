import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/tag.dart';
import 'package:ticktodo/l10n/app_localizations.dart';

class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  final _nameCtrl = TextEditingController();
  int _color = kPalette.first;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _createTag() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    await ref.read(metaRepoProvider).upsertTag(Tag(name: name, color: _color));
    _nameCtrl.clear();
    bumpMutation(ref);
  }

  Future<void> _deleteTag(Tag tag) async {
    await ref.read(metaRepoProvider).softDeleteTag(tag.id!);
    bumpMutation(ref);
  }

  Future<void> _renameTag(Tag tag) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: tag.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tagRenameTitle),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    await ref
        .read(metaRepoProvider)
        .upsertTag(tag.copyWith(name: newName));
    bumpMutation(ref);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tags = ref.watch(tagsProvider).valueOrNull ?? const <Tag>[];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tagManageTitle)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                for (final tag in tags)
                  ListTile(
                    leading: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Color(tag.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(tag.name),
                    onTap: () => _renameTag(tag),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteTag(tag),
                    ),
                  ),
                if (tags.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(child: Text(l10n.tagEmpty)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      hintText: l10n.tagNameHint,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _createTag(),
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
                  onPressed: _createTag,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
