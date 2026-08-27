import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui show AppExitType;
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/features/all/all_screen.dart';
import 'package:ticktodo/features/calendar/calendar_screen.dart';
import 'package:ticktodo/features/filters/filters_screen.dart';
import 'package:ticktodo/features/focus/focus_screen.dart';
import 'package:ticktodo/features/habits/habits_screen.dart';
import 'package:ticktodo/features/matrix/matrix_screen.dart';
import 'package:ticktodo/features/search/search_screen.dart';
import 'package:ticktodo/features/settings/settings_screen.dart';
import 'package:ticktodo/features/today/today_screen.dart';
import 'package:ticktodo/features/trash/trash_screen.dart';
import 'package:ticktodo/features/week/week_screen.dart';
import 'package:ticktodo/l10n/app_localizations.dart';
import 'package:ticktodo/widgets/quick_add_sheet.dart';

/// macOS 桌面外壳：左侧边栏导航 + 内容区 + 平台菜单栏 + 键盘快捷键。
///
/// 遵循 macOS HIG：
/// - 侧边栏为标准三窗格布局的导航栏，选中项圆角高亮、悬停反馈
/// - 应用菜单栏（文件/编辑/视图/窗口）与系统快捷键约定一致
/// - 无移动端 FAB；新建走 Cmd+N 或侧边栏"+"按钮
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  int _index = 0;

  static const _viewKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
  ];

  void _openQuickAdd() {
    showQuickAdd(context,
        defaultDueDate: _index == 0, isFloatingOnDesktop: true);
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  void _openTrash() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TrashScreen()),
    );
  }

  void _openFilters() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FiltersScreen()),
    );
  }

  void _openHabits() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HabitsScreen()),
    );
  }

  void _openFocus() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FocusScreen()),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  String _viewLabel(int i, AppLocalizations l10n) => switch (i) {
        0 => l10n.navToday,
        1 => l10n.navWeek,
        2 => l10n.navCalendar,
        3 => l10n.navAllTasks,
        _ => l10n.navMatrix,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return PlatformMenuBar(
      menus: [
        PlatformMenu(label: l10n.desktopMenuApp, menus: [
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: l10n.desktopMenuAbout,
              onSelected: () => showAboutDialog(context: context),
            ),
          ]),
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: l10n.desktopMenuSettings,
              onSelected: _openSettings,
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.comma, meta: true),
            ),
          ]),
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: l10n.desktopMenuQuit,
              onSelected: () =>
                  ServicesBinding.instance.exitApplication(ui.AppExitType.required),
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyQ, meta: true),
            ),
          ]),
        ]),
        PlatformMenu(label: l10n.desktopMenuFile, menus: [
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: l10n.desktopMenuNewTask,
              onSelected: _openQuickAdd,
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyN, meta: true),
            ),
            PlatformMenuItem(
              label: l10n.desktopMenuSearch,
              onSelected: _openSearch,
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyF, meta: true),
            ),
          ]),
        ]),
        PlatformMenu(label: l10n.desktopMenuView, menus: [
          for (var i = 0; i < 5; i++)
            PlatformMenuItem(
              label: '${i + 1}. ${_viewLabel(i, l10n)}',
              onSelected: () => setState(() => _index = i),
              shortcut: SingleActivator(
                [
                  LogicalKeyboardKey.digit1,
                  LogicalKeyboardKey.digit2,
                  LogicalKeyboardKey.digit3,
                  LogicalKeyboardKey.digit4,
                ][i],
                meta: true,
              ),
            ),
        ]),
        PlatformMenu(label: l10n.desktopMenuHelp, menus: [
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: l10n.desktopMenuShortcuts,
              onSelected: () => showDialog<void>(
                context: context,
                builder: (ctx) => const _ShortcutsDialog(),
              ),
            ),
          ]),
        ]),
      ],
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
              _openQuickAdd,
          const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
              _openSearch,
          for (var i = 0; i < _viewKeys.length; i++)
            SingleActivator(_viewKeys[i], meta: true): () =>
                setState(() => _index = i),
        },
        child: Scaffold(
          body: Row(
            children: [
              _Sidebar(
                selectedIndex: _index,
                onSelect: (i) => setState(() => _index = i),
                onQuickAdd: _openQuickAdd,
                onSearch: _openSearch,
                onOpenTrash: _openTrash,
                onOpenSettings: _openSettings,
                onOpenFilters: _openFilters,
                onOpenHabits: _openHabits,
                onOpenFocus: _openFocus,
              ),
              VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: const [
                    TodayScreen(desktopMode: true),
                    WeekScreen(desktopMode: true),
                    CalendarScreen(),
                    AllScreen(desktopMode: true),
                    MatrixScreen(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- 侧边栏 ----------

class _Sidebar extends ConsumerStatefulWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.onSelect,
    required this.onQuickAdd,
    required this.onSearch,
    required this.onOpenTrash,
    required this.onOpenSettings,
    required this.onOpenFilters,
    required this.onOpenHabits,
    required this.onOpenFocus,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onQuickAdd;
  final VoidCallback onSearch;
  final VoidCallback onOpenTrash;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenFilters;
  final VoidCallback onOpenHabits;
  final VoidCallback onOpenFocus;

  @override
  ConsumerState<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<_Sidebar> {
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final lists = ref.watch(listsProvider).valueOrNull ?? const [];

    return SizedBox(
      width: 232,
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题（位于系统标题栏下方）
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: theme.colorScheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(l10n.appTitle,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            // 智能清单
            _sectionHeader(l10n.desktopSidebarFilters),
            _item(
              index: 0,
              icon: Icons.today_outlined,
              selectedIcon: Icons.today,
              label: l10n.navToday,
            ),
            _item(
              index: 1,
              icon: Icons.date_range_outlined,
              selectedIcon: Icons.date_range,
              label: l10n.navWeek,
            ),
            _item(
              index: 2,
              icon: Icons.calendar_month_outlined,
              selectedIcon: Icons.calendar_month,
              label: l10n.navCalendar,
            ),
            _item(
              index: 3,
              icon: Icons.checklist_outlined,
              selectedIcon: Icons.checklist,
              label: l10n.navAllTasks,
            ),
            _item(
              index: 4,
              icon: Icons.grid_view_outlined,
              selectedIcon: Icons.grid_view,
              label: l10n.navMatrix,
            ),
            if (lists.isNotEmpty) ...[
              _sectionHeader(l10n.navLists),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final l in lists)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: InkWell(
                          onTap: () => widget.onSelect(3),
                          borderRadius: BorderRadius.circular(6),
                          child: Row(
                            children: [
                              Icon(Icons.circle,
                                  size: 9, color: Color(l.color)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(l.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const Spacer(),
            const Divider(height: 1, indent: 12, endIndent: 12),
            const SizedBox(height: 6),
            _actionTile(Icons.add, l10n.desktopNewTask, widget.onQuickAdd),
            _actionTile(Icons.search, l10n.desktopSearch, widget.onSearch),
            _actionTile(
                Icons.filter_alt_outlined, l10n.navFilters, widget.onOpenFilters),
            _actionTile(
                Icons.repeat_one_outlined, l10n.navHabits, widget.onOpenHabits),
            _actionTile(
                Icons.timer_outlined, l10n.navFocus, widget.onOpenFocus),
            _actionTile(
                Icons.delete_outline, l10n.navTrash, widget.onOpenTrash),
            _actionTile(
                Icons.settings_outlined, l10n.desktopSettingsCmd, widget.onOpenSettings),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.outline,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _item({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final theme = Theme.of(context);
    final selected = widget.selectedIndex == index;
    final hovered = _hoverIndex == index && !selected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hoverIndex = index),
        onExit: (_) => setState(() => _hoverIndex = null),
        child: GestureDetector(
          onTap: () => widget.onSelect(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.secondaryContainer
                  : hovered
                      ? theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.6)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 18,
                  color: selected
                      ? theme.colorScheme.onSecondaryContainer
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.chevron_right,
                      size: 14, color: theme.colorScheme.onSecondaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              Icon(icon, size: 17, color: theme.colorScheme.outline),
              const SizedBox(width: 9),
              Text(label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- 快捷键说明弹窗 ----------

class _ShortcutsDialog extends StatelessWidget {
  const _ShortcutsDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rows = <(String, String)>[
      ('⌘N', l10n.desktopNewTask),
      ('⌘F', l10n.desktopSearch),
      ('⌘1', l10n.navToday),
      ('⌘2', l10n.navWeek),
      ('⌘3', l10n.navCalendar),
      ('⌘4', l10n.navAllTasks),
      ('⌘,', l10n.navSettings),
      ('⌘Q', l10n.desktopShortcutQuit),
    ];
    return AlertDialog(
      title: Text(l10n.desktopShortcutsTitle),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (key, desc) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(desc),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Text(key,
                          style: Theme.of(context).textTheme.labelSmall),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonOk),
        ),
      ],
    );
  }
}
