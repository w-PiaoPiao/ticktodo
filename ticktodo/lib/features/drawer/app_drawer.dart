import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/features/filters/filters_screen.dart';
import 'package:ticktodo/features/focus/focus_screen.dart';
import 'package:ticktodo/features/habits/habits_screen.dart';
import 'package:ticktodo/features/lists/lists_screen.dart';
import 'package:ticktodo/features/search/search_screen.dart';
import 'package:ticktodo/features/settings/settings_screen.dart';
import 'package:ticktodo/features/tags/tags_screen.dart';
import 'package:ticktodo/features/trash/trash_screen.dart';
import 'package:ticktodo/l10n/app_localizations.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key, this.onNavigate});

  /// 底部导航切换回调（null 表示通过根导航器）
  final void Function(int tabIndex)? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final lists = ref.watch(listsProvider).valueOrNull ?? const [];
    final sync = ref.read(syncManagerProvider);
    final settings = ref.read(syncSettingsProvider);

    final syncOk = settings.hasCredentials && sync.lastResult?.success != false;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.appTitle,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text(
                          settings.hasCredentials
                              ? (syncOk ? l10n.kvSyncOk : l10n.kvSyncDown)
                              : l10n.kvSyncNone,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.today_outlined),
              title: Text(l10n.navToday),
              onTap: () {
                Navigator.pop(context);
                onNavigate?.call(0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range_outlined),
              title: Text(l10n.navWeek),
              onTap: () {
                Navigator.pop(context);
                onNavigate?.call(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: Text(l10n.navCalendar),
              onTap: () {
                Navigator.pop(context);
                onNavigate?.call(2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: Text(l10n.navAllTasks),
              onTap: () {
                Navigator.pop(context);
                onNavigate?.call(3);
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Text(l10n.navLists,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.outline)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ListsScreen()),
                    ),
                  ),
                ],
              ),
            ),
            for (final list in lists.take(8))
              ListTile(
                dense: true,
                leading: Icon(Icons.circle, size: 10, color: Color(list.color)),
                title: Text(list.name),
                onTap: () {
                  Navigator.pop(context);
                  onNavigate?.call(3);
                },
              ),
            ListTile(
              leading: const Icon(Icons.label_outline),
              title: Text(l10n.navTags),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TagsScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.filter_alt_outlined),
              title: Text(l10n.navFilters),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FiltersScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.repeat_one_outlined),
              title: Text(l10n.navHabits),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HabitsScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: Text(l10n.navFocus),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FocusScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: Text(l10n.navSearch),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.navTrash),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TrashScreen()),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(l10n.navSettings),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
