import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/core/theme.dart';
import 'package:ticktodo/features/all/all_screen.dart';
import 'package:ticktodo/features/calendar/calendar_screen.dart';
import 'package:ticktodo/features/drawer/app_drawer.dart';
import 'package:ticktodo/features/today/today_screen.dart';
import 'package:ticktodo/features/week/week_screen.dart';

class TickTodoApp extends ConsumerWidget {
  const TickTodoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: '滴答清单Pro',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      home: const HomeShell(),
    );
  }
}

/// 底部导航 + 抽屉外壳
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(onNavigate: (i) => setState(() => _index = i)),
      body: IndexedStack(
        index: _index,
        children: const [
          TodayScreen(),
          WeekScreen(),
          CalendarScreen(),
          AllScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: '今天'),
          NavigationDestination(icon: Icon(Icons.date_range_outlined), selectedIcon: Icon(Icons.date_range), label: '最近7天'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: '日历'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: '全部'),
        ],
      ),
    );
  }
}
