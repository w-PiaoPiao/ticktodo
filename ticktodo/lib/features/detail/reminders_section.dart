import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/l10n/app_localizations.dart';

/// 详情页：额外提醒时间列表 + 添加/删除（与主提醒"提前 N 分钟"互补）。
class RemindersSection extends ConsumerStatefulWidget {
  const RemindersSection({super.key, required this.task, required this.onChanged});

  final Task task;
  final VoidCallback onChanged;

  @override
  ConsumerState<RemindersSection> createState() => _RemindersSectionState();
}

class _RemindersSectionState extends ConsumerState<RemindersSection> {
  List<int> _epochs = [];
  bool _loaded = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RemindersSection old) {
    super.didUpdateWidget(old);
    if (old.task.id != widget.task.id) _load();
  }

  Future<void> _load() async {
    final list =
        await ref.read(taskRepoProvider).queryRemindersOf(widget.task.id!);
    if (!mounted) return;
    setState(() {
      _epochs = list.map((e) => e.remindAt).toList();
      _loaded = true;
      _loading = false;
    });
  }

  Future<void> _persist(List<int> epochs) async {
    await ref.read(taskRepoProvider).setReminders(widget.task.id!, epochs..sort());
    widget.onChanged();
    await _load();
  }

  Future<void> _addReminder() async {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: l10n.remindersPickDateHelp,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: l10n.remindersPickTimeHelp,
    );
    if (time == null || !mounted) return;
    final epoch = DateTime(date.year, date.month, date.day, time.hour, time.minute)
        .millisecondsSinceEpoch;
    if (_epochs.contains(epoch)) return;
    await _persist([..._epochs, epoch]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    if (!_loaded && _loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
            height: 20, width: 20,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(Icons.notifications_active_outlined, size: 20, color: theme.colorScheme.outline),
              const SizedBox(width: 12),
              Text(l10n.remindersTitle, style: theme.textTheme.bodyLarge),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                tooltip: l10n.remindersAddTooltip,
                onPressed: _addReminder,
              ),
            ],
          ),
        ),
        if (_epochs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(l10n.remindersEmpty,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final e in _epochs)
                InputChip(
                  avatar: const Icon(Icons.alarm, size: 15),
                  label: Text(DateFormat(l10n.remindersFormatMd)
                      .format(DateTime.fromMillisecondsSinceEpoch(e))),
                  visualDensity: VisualDensity.compact,
                  onDeleted: () => _persist(_epochs.where((x) => x != e).toList()),
                ),
            ],
          ),
      ],
    );
  }
}
