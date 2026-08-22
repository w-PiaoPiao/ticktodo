import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/models/habit.dart';
import 'package:ticktodo/features/habits/habit_edit_sheet.dart';
import 'package:ticktodo/widgets/empty_state.dart';

/// 习惯页：今日打卡列表 + 连续天数 + 近 5 周热力图。
class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  List<Habit>? _habits;
  final Map<int, bool> _checkedToday = {};
  final Map<int, int> _streaks = {};
  final Map<int, Set<String>> _recentDates = {};

  @override
  void initState() {
    super.initState();
    ref.listenManual(taskMutationProvider, (_, _) => _load());
    _load();
  }

  Future<void> _load() async {
    final habits = await ref.read(habitRepoProvider).queryHabits();
    final repo = ref.read(habitRepoProvider);
    final todayStr = DateUtilsEx.formatDate(DateTime.now());
    for (final h in habits) {
      if (h.id == null) continue;
      _checkedToday[h.id!] = await repo.isCheckedOn(h.id!, todayStr);
      _streaks[h.id!] = await repo.currentStreak(h.id!);
      _recentDates[h.id!] =
          await _loadRecent(h.id!);
    }
    if (!mounted) return;
    setState(() => _habits = habits);
  }

  Future<Set<String>> _loadRecent(int habitId) async {
    final now = DateTime.now();
    final start =
        DateTime(now.year, now.month, now.day).subtract(const Duration(days: 34));
    return ref.read(habitRepoProvider).checkedDates(habitId,
        start: DateUtilsEx.formatDate(start),
        end: DateUtilsEx.formatDate(now));
  }

  Future<void> _toggle(Habit h) async {
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

  Future<void> _archive(Habit h) async {
    await ref.read(habitRepoProvider).archiveHabit(h.id!);
    bumpMutation(ref);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final habits = _habits;
    return Scaffold(
      appBar: AppBar(title: const Text('习惯')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-habits',
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
      body: habits == null
          ? const Center(child: CircularProgressIndicator())
          : habits.isEmpty
              ? EmptyState(
                  icon: Icons.repeat_one_outlined,
                  title: '还没有习惯',
                  subtitle: '点击右下角 + 创建第一个习惯',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 88),
                    children: [
                      for (final h in habits)
                        _HabitCard(
                          habit: h,
                          checkedToday: _checkedToday[h.id] ?? false,
                          streak: _streaks[h.id] ?? 0,
                          recentDates:
                              _recentDates[h.id] ?? const {},
                          onToggle: () => _toggle(h),
                          onTap: () => _openEditor(h),
                          onLongPress: () => _archive(h),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('长按卡片可归档习惯',
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
    required this.recentDates,
    required this.onToggle,
    required this.onTap,
    required this.onLongPress,
  });

  final Habit habit;
  final bool checkedToday;
  final int streak;
  final Set<String> recentDates;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                          ? const Icon(Icons.check, size: 20, color: Colors.white)
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
                      label: Text('$streak 天',
                          style: theme.textTheme.labelSmall),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: const Color(0x1AF29900),
                    ),
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
