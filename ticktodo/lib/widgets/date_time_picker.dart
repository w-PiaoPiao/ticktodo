import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/l10n/app_localizations.dart';

/// 任务详情页的日期/时间/提醒选择区
class DateTimeSection extends StatefulWidget {
  const DateTimeSection({
    super.key,
    required this.task,
    required this.onChanged,
  });

  final Task task;
  final ValueChanged<Task> onChanged;

  @override
  State<DateTimeSection> createState() => _DateTimeSectionState();
}

class _DateTimeSectionState extends State<DateTimeSection> {
  late DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate =
        widget.task.dueDate == null ? null : DateUtilsEx.parseDate(widget.task.dueDate!);
  }

  @override
  void didUpdateWidget(covariant DateTimeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.dueDate != widget.task.dueDate) {
      _selectedDate =
          widget.task.dueDate == null ? null : DateUtilsEx.parseDate(widget.task.dueDate!);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
    final dueTime = widget.task.dueTime;
    widget.onChanged(widget.task.copyWith(
      dueDate: DateUtilsEx.formatDate(picked),
      dueTime: dueTime,
    ));
  }

  Future<void> _pickTime() async {
    final initial = widget.task.dueTime == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : () {
            final t = DateUtilsEx.parseTime(widget.task.dueTime!)!;
            return TimeOfDay(hour: t.hour, minute: t.minute);
          }();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    widget.onChanged(
        widget.task.copyWith(dueTime: DateUtilsEx.formatTimeOfDay(picked)));
  }

  Future<void> _pickReminder() async {
    final l10n = AppLocalizations.of(context);
    final options = <String, int?>{
      l10n.dateNoReminder: null,
      l10n.dateAtDue: 0,
      l10n.dateAhead5m: -5,
      l10n.dateAhead15m: -15,
      l10n.dateAhead30m: -30,
      l10n.dateAhead1h: -60,
      l10n.dateAhead1d: -24 * 60,
      l10n.dateCustomTime: -999,
    };
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final e in options.entries)
              ListTile(
                title: Text(e.key),
                trailing: e.value == 0
                    ? null
                    : (e.value == null ? null : const Icon(Icons.schedule)),
                onTap: () => Navigator.pop(ctx, e.key),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    if (!mounted) return;

    final offsetMin = options[selected];
    if (offsetMin == null) {
      widget.onChanged(widget.task.copyWith(clearRemindAt: true));
      return;
    }
    if (offsetMin == -999) {
      final base = widget.task.dueDate == null
          ? DateTime.now()
          : DateUtilsEx.parseDate(widget.task.dueDate!);
      final time = widget.task.dueTime == null
          ? DateTime(2000, 1, 1, 9, 0)
          : DateUtilsEx.parseTime(widget.task.dueTime!)!;
      final dt = DateTime(base.year, base.month, base.day, time.hour, time.minute);
      final picked = await showDatePicker(
        context: context,
        initialDate: dt,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );
      if (picked == null) return;
      if (!mounted) return;
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: picked.hour, minute: picked.minute),
      );
      if (t == null) return;
      if (!mounted) return;
      final remindDt = DateTime(picked.year, picked.month, picked.day, t.hour, t.minute);
      widget.onChanged(
          widget.task.copyWith(remindAt: remindDt.millisecondsSinceEpoch));
      return;
    }
    // 相对到期时间的偏移
    final dueDate = widget.task.dueDate ?? DateUtilsEx.formatDate(DateTime.now());
    final dueTime = widget.task.dueTime ?? '09:00';
    final dueDt = DateUtilsEx.parseDate(dueDate);
    final t = DateUtilsEx.parseTime(dueTime)!;
    final dt = DateTime(dueDt.year, dueDt.month, dueDt.day, t.hour, t.minute)
        .add(Duration(minutes: offsetMin));
    widget.onChanged(
        widget.task.copyWith(remindAt: dt.millisecondsSinceEpoch));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final overdue = widget.task.dueDate != null &&
        isOverdue(widget.task.dueDate!);

    return Column(
      children: [
        ListTile(
          dense: true,
          leading: const Icon(Icons.calendar_today_outlined, size: 20),
          title: Text(
            widget.task.dueDate == null
                ? l10n.dateAddDate
                : dateBadge(widget.task.dueDate!, l10n),
            style: TextStyle(
              color: overdue ? const Color(AppColors.overDueRed) : null,
            ),
          ),
          trailing: widget.task.dueDate == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () =>
                      widget.onChanged(widget.task.copyWith(clearDueDate: true)),
                ),
          onTap: _pickDate,
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.access_time, size: 20),
          title: Text(widget.task.dueTime == null ? l10n.dateAddTime : widget.task.dueTime!),
          trailing: widget.task.dueTime == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () =>
                      widget.onChanged(widget.task.copyWith(clearDueTime: true)),
                ),
          onTap: _pickTime,
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.notifications_none, size: 20),
          title: Text(
            widget.task.remindAt == null
                ? l10n.dateRemindMe
                : DateFormat(l10n.remindersFormatMd)
                    .format(DateTime.fromMillisecondsSinceEpoch(widget.task.remindAt!)),
          ),
          trailing: widget.task.remindAt == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () =>
                      widget.onChanged(widget.task.copyWith(clearRemindAt: true)),
                ),
          onTap: _pickReminder,
        ),
      ],
    );
  }
}
