import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/habit.dart';

/// 习惯新建/编辑底部表单。
class HabitEditSheet extends ConsumerStatefulWidget {
  const HabitEditSheet({super.key, this.existing});

  final Habit? existing;

  @override
  ConsumerState<HabitEditSheet> createState() => _HabitEditSheetState();
}

class _HabitEditSheetState extends ConsumerState<HabitEditSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late int _color = widget.existing?.color ?? kPalette.first;
  late int _targetDays = widget.existing?.targetDays ?? 0;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    await ref.read(habitRepoProvider).upsertHabit(Habit(
          id: widget.existing?.id,
          name: name,
          color: _color,
          targetDays: _targetDays,
          archived: widget.existing?.archived ?? false,
          sortOrder: widget.existing?.sortOrder ?? 0,
          createdAt: widget.existing?.createdAt, // 编辑时保留原创建时间
        ));
    bumpMutation(ref);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          Text(widget.existing == null ? '新建习惯' : '编辑习惯',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '习惯名称',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          Text('颜色', style: theme.textTheme.labelMedium),
          Wrap(
            spacing: 8,
            children: [
              for (final c in kPalette)
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: _color == c ? 3 : 0,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('每周目标', style: theme.textTheme.labelMedium),
          Wrap(
            spacing: 6,
            children: [
              ChoiceChip(
                label: const Text('每天'),
                selected: _targetDays == 0,
                onSelected: (_) => setState(() => _targetDays = 0),
              ),
              for (var d = 1; d <= 6; d++)
                ChoiceChip(
                  label: Text('$d 天/周'),
                  selected: _targetDays == d,
                  onSelected: (_) => setState(() => _targetDays = d),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
