import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/habit.dart';
import 'package:ticktodo/data/repositories/habit_repository.dart';
import 'package:ticktodo/features/habits/habit_edit_sheet.dart';
import 'package:ticktodo/l10n/app_localizations.dart';
import 'package:ticktodo/widgets/empty_state.dart';

/// 习惯页：今日打卡列表 + 连续天数 + 本周进度 + 近 5 周热力图。
///
/// 支持查看已归档习惯并恢复；卡片菜单提供归档/删除入口。
class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  List<HabitWithStats>? _rows;
  bool _showArchived = false;
  ProviderSubscription<int>? _mutationSub;

  @override
  void initState() {
    super.initState();
    _mutationSub = ref.listenManual(taskMutationProvider, (_, _) => _load());
    _load();
  }

  @override
  void dispose() {
    _mutationSub?.close();
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await ref
        .read(habitRepoProvider)
        .habitsWithStats(includeArchived: _showArchived);
    if (!mounted) return;
    setState(() => _rows = rows);
  }

  Future<void> _toggle(Habit h) async {
    if (h.archived || h.id == null) return;
    final todayStr = DateUtilsEx.formatDate(DateTime.now());
    await ref.read(habitRepoProvider).toggleCheck(h.id!, todayStr);
    bumpMutation(ref);
    _load();
  }

  Future<void> _openEditor([Habit? existing]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => HabitEditSheet(existing: existing),
    );
    if (saved == true) _load();
  }

  Future<void> _setArchived(Habit h, {required bool archived}) async {
    await ref.read(habitRepoProvider).archiveHabit(h.id!, archived: archived);
    bumpMutation(ref);
    _load();
  }

  Future<void> _delete(Habit h) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.habitDeleteTitle),
        content: Text(l10n.habitDeleteConfirm(h.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || h.id == null) return;
    await ref.read(habitRepoProvider).softDeleteHabit(h.id!);
    bumpMutation(ref);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(
        title: Text(_showArchived ? l10n.habitArchivedTitle : l10n.habitsTitle),
        actions: [
          IconButton(
            tooltip: _showArchived ? l10n.habitBackToList : l10n.habitViewArchived,
            icon: Icon(_showArchived
                ? Icons.repeat_one_outlined
                : Icons.inventory_2_outlined),
            onPressed: () {
              setState(() {
                _showArchived = !_showArchived;
                _rows = null;
              });
              _load();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-habits',
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
      body: rows == null
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
              ? EmptyState(
                  icon: _showArchived
                      ? Icons.inventory_2_outlined
                      : Icons.repeat_one_outlined,
                  title: _showArchived ? l10n.habitArchivedEmpty : l10n.habitEmpty,
                  subtitle: _showArchived
                      ? l10n.habitArchivedHint
                      : l10n.habitCreateFirst,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 88),
                    children: [
                      for (final r in rows)
                        _HabitCard(
                          habit: r.habit,
                          checkedToday: r.checkedToday,
                          streak: r.streak,
                          weekCount: r.weekCount,
                          recentDates: r.recentDates,
                          onToggle: () => _toggle(r.habit),
                          onTap: () => _openEditor(r.habit),
                          onLongPress: r.habit.archived
                              ? null
                              : () =>
                                  _setArchived(r.habit, archived: true),
                          onArchiveToggle: () => _setArchived(
                              r.habit, archived: !r.habit.archived),
                          onDelete: () => _delete(r.habit),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                            _showArchived
                                ? l10n.habitArchivedTip
                                : l10n.habitCardTip,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline)),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ---------- 单个习惯卡片 ----------

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.habit,
    required this.checkedToday,
    required this.streak,
    required this.weekCount,
    required this.recentDates,
    required this.onToggle,
    required this.onTap,
    required this.onLongPress,
    required this.onArchiveToggle,
    required this.onDelete,
  });

  final Habit habit;
  final bool checkedToday;
  final int streak;
  final int weekCount;
  final Set<String> recentDates;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onArchiveToggle;
  final VoidCallback onDelete;

  /// 每周目标上限：0（每天）按 7 天展示。
  int get _weeklyTarget => habit.targetDays == 0 ? 7 : habit.targetDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = Color(habit.color);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (habit.archived)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(Icons.archive_outlined,
                          size: 22, color: theme.colorScheme.outline),
                    )
                  else
                    InkWell(
                      onTap: onToggle,
                      customBorder: const CircleBorder(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: checkedToday ? color : Colors.transparent,
                          border: Border.all(color: color, width: 2),
                        ),
                        child: checkedToday
                            ? const Icon(Icons.check,
                                size: 20, color: Colors.white)
                            : null,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(habit.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600)),
                  ),
                  if (streak > 0)
                    Chip(
                      avatar: const Icon(Icons.local_fire_department,
                          size: 15, color: Color(0xFFF29900)),
                      label: Text(l10n.habitStreakDays(streak),
                          style: theme.textTheme.labelSmall),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: const Color(0x1AF29900),
                    ),
                  Chip(
                    label: Text(l10n.habitWeekProgress(weekCount, _weeklyTarget),
                        style: theme.textTheme.labelSmall),
                    visualDensity: VisualDensity.compact,
                  ),
                  _cardMenu(context),
                ],
              ),
              const SizedBox(height: 10),
              HabitHeatmap(
                color: habit.color,
                checkedDates: recentDates,
                weeks: 5,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      tooltip: l10n.habitMoreTooltip,
      onSelected: (action) {
        switch (action) {
          case 'archive':
            onArchiveToggle();
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'archive',
          child: ListTile(
            leading: Icon(habit.archived
                ? Icons.unarchive_outlined
                : Icons.archive_outlined),
            title: Text(habit.archived ? l10n.habitRestore : l10n.habitArchive),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline,
                color: Theme.of(context).colorScheme.error),
            title: Text(l10n.commonDelete,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error)),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

// ---------- 热力图 ----------

/// 近 N 周 GitHub 风格热力图（列=周，行=周一到周日）。
class HabitHeatmap extends StatelessWidget {
  const HabitHeatmap({
    super.key,
    required this.color,
    required this.checkedDates,
    this.weeks = 5,
  });

  final int color;
  final Set<String> checkedDates;
  final int weeks;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 本周周一
    final thisMonday = today.subtract(Duration(days: now.weekday - 1));
    final startMonday = thisMonday.subtract(Duration(days: 7 * (weeks - 1)));

    Widget cell(DateTime day) {
      final isFuture = day.isAfter(today);
      final dateStr = DateUtilsEx.formatDate(day);
      final done = checkedDates.contains(dateStr);
      return Container(
        width: 16,
        height: 16,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          color: isFuture
              ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
              : done
                  ? Color(color)
                  : Color(color).withValues(alpha: 0.15),
        ),
      );
    }

    return SizedBox(
      height: 16 * 7 + 12,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var w = 0; w < weeks; w++)
              Column(
                children: [
                  for (var d = 0; d < 7; d++)
                    cell(startMonday.add(Duration(days: w * 7 + d))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
