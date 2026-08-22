import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/core/theme.dart';
import 'package:ticktodo/core/widget_bridge.dart';
import 'package:ticktodo/features/all/all_screen.dart';
import 'package:ticktodo/features/calendar/calendar_screen.dart';
import 'package:ticktodo/features/desktop/desktop_shell.dart';
import 'package:ticktodo/features/drawer/app_drawer.dart';
import 'package:ticktodo/features/matrix/matrix_screen.dart';
import 'package:ticktodo/features/today/today_screen.dart';
import 'package:ticktodo/features/week/week_screen.dart';

/// 全局导航 key：供通知点击跳转使用
final appNavigatorKey = GlobalKey<NavigatorState>();

class TickTodoApp extends ConsumerStatefulWidget {
  const TickTodoApp({super.key, this.initialTaskId, this.onOpenTask});

  /// 冷启动时由通知携带的任务 id
  final int? initialTaskId;

  /// 打开任务详情（由 main 注入，与通知点击同一逻辑）
  final void Function(int taskId)? onOpenTask;

  @override
  ConsumerState<TickTodoApp> createState() => _TickTodoAppState();
}

class _TickTodoAppState extends ConsumerState<TickTodoApp> {
  @override
  void initState() {
    super.initState();
    // 冷启动通知：首帧渲染完成后跳转对应任务
    final taskId = widget.initialTaskId;
    if (taskId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onOpenTask?.call(taskId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: '滴答清单Pro',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
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
  String? _widgetDate;

  @override
  void initState() {
    super.initState();
    _loadWidgetDate();
  }

  /// 小部件点击 → 打开日历视图并定位日期
  Future<void> _loadWidgetDate() async {
    final date = await getStartupDate();
    if (date != null && date.isNotEmpty && mounted) {
      setState(() {
        _widgetDate = date;
        _index = 2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 桌面端（macOS/Windows/Linux）使用侧边栏外壳；移动端保持底部导航。
    // 用 defaultTargetPlatform 而非 Platform，保证 widget 测试环境可覆盖。
    final isDesktop = !kIsWeb &&
        switch (defaultTargetPlatform) {
          TargetPlatform.macOS ||
          TargetPlatform.windows ||
          TargetPlatform.linux => true,
          _ => false,
        };
    if (isDesktop) {
      return const DesktopShell();
    }
    return Scaffold(
      drawer: AppDrawer(onNavigate: (i) => setState(() => _index = i)),
      body: IndexedStack(
        index: _index,
        children: [
          const TodayScreen(),
          const WeekScreen(),
          CalendarScreen(initialDate: _widgetDate),
          const AllScreen(),
          const MatrixScreen(),
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
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: '四象限'),
        ],
      ),
    );
  }
}
