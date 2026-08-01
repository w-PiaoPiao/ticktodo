import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/features/lists/lists_screen.dart';
import 'package:ticktodo/features/settings/settings_screen.dart';
import 'package:ticktodo/features/tags/tags_screen.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key, this.onNavigate});

  /// 底部导航切换回调（null 表示通过根导航器）
  final void Function(int tabIndex)? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
                        Text('滴答清单Pro',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Text(
                          settings.hasCredentials
                              ? (syncOk ? '坚果云已同步' : '坚果云未连接')
                              : '未配置同步',
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
              title: const Text('今天'),
              onTap: () {
                Navigator.pop(context);
                onNavigate?.call(0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range_outlined),
              title: const Text('最近7天'),
              onTap: () {
                Navigator.pop(context);
                onNavigate?.call(1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('日历'),
              onTap: () {
                Navigator.pop(context);
                onNavigate?.call(2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: const Text('全部任务'),
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
                  Text('清单',
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
              title: const Text('标签管理'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TagsScreen()),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('设置'),
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
