import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui show AppExitType;
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/features/all/all_screen.dart';
import 'package:ticktodo/features/calendar/calendar_screen.dart';
import 'package:ticktodo/features/search/search_screen.dart';
import 'package:ticktodo/features/settings/settings_screen.dart';
import 'package:ticktodo/features/today/today_screen.dart';
import 'package:ticktodo/features/trash/trash_screen.dart';
import 'package:ticktodo/features/week/week_screen.dart';
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

  static const _viewLabels = ['今天', '最近7天', '日历', '全部任务'];
  static const _viewKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
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

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PlatformMenuBar(
      menus: [
        PlatformMenu(label: '滴答清单Pro', menus: [
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: '关于滴答清单Pro',
              onSelected: () => showAboutDialog(context: context),
            ),
          ]),
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: '设置…',
              onSelected: _openSettings,
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.comma, meta: true),
            ),
          ]),
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: '退出滴答清单Pro',
              onSelected: () =>
                  ServicesBinding.instance.exitApplication(ui.AppExitType.required),
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyQ, meta: true),
            ),
          ]),
        ]),
        PlatformMenu(label: '文件', menus: [
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: '新建任务…',
              onSelected: _openQuickAdd,
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyN, meta: true),
            ),
            PlatformMenuItem(
              label: '搜索…',
              onSelected: _openSearch,
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyF, meta: true),
            ),
          ]),
        ]),
        PlatformMenu(label: '视图', menus: [
          for (var i = 0; i < _viewLabels.length; i++)
            PlatformMenuItem(
              label: '${i + 1}. ${_viewLabels[i]}',
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
        PlatformMenu(label: '帮助', menus: [
          PlatformMenuItemGroup(members: [
            PlatformMenuItem(
              label: '键盘快捷键',
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
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onQuickAdd;
  final VoidCallback onSearch;
  final VoidCallback onOpenTrash;
  final VoidCallback onOpenSettings;

  @override
  ConsumerState<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<_Sidebar> {
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  Text('滴答清单Pro',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            // 智能清单
            _sectionHeader('智能清单'),
            _item(
              index: 0,
              icon: Icons.today_outlined,
              selectedIcon: Icons.today,
              label: '今天',
            ),
            _item(
              index: 1,
              icon: Icons.date_range_outlined,
              selectedIcon: Icons.date_range,
              label: '最近7天',
            ),
            _item(
              index: 2,
              icon: Icons.calendar_month_outlined,
              selectedIcon: Icons.calendar_month,
              label: '日历',
            ),
            _item(
              index: 3,
              icon: Icons.checklist_outlined,
              selectedIcon: Icons.checklist,
              label: '全部任务',
            ),
            if (lists.isNotEmpty) ...[
              _sectionHeader('清单'),
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
            _actionTile(Icons.add, '新建任务', widget.onQuickAdd),
            _actionTile(Icons.search, '搜索', widget.onSearch),
            _actionTile(Icons.delete_outline, '回收站', widget.onOpenTrash),
            _actionTile(Icons.settings_outlined, '设置 ⌘,', widget.onOpenSettings),
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

  static const _rows = <(String, String)>[
    ('⌘N', '新建任务'),
    ('⌘F', '搜索'),
    ('⌘1', '今天'),
    ('⌘2', '最近7天'),
    ('⌘3', '日历'),
    ('⌘4', '全部任务'),
    ('⌘,', '设置'),
    ('⌘Q', '退出'),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('键盘快捷键'),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (key, desc) in _rows)
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
          child: const Text('好'),
        ),
      ],
    );
  }
}
