import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ticktodo/app.dart';
import 'package:ticktodo/backup/local_backup.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/core/logger.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/repositories/habit_repository.dart';
import 'package:ticktodo/data/repositories/pomodoro_repository.dart';
import 'package:ticktodo/data/repositories/task_repository.dart';
import 'package:ticktodo/features/detail/task_detail_screen.dart';
import 'package:ticktodo/l10n/app_localizations.dart';
import 'package:ticktodo/notifications/notification_service.dart';
import 'package:ticktodo/sync/credential_store.dart';
import 'package:ticktodo/sync/sync_manager.dart';
import 'package:ticktodo/sync/sync_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _bootstrapAndRun();
  } catch (e, s) {
    // 启动期兜底：任何初始化失败都必须可见（错误页 + 日志），
    // 绝不允许 runApp 前静默抛错 → 黑窗口无内容。
    AppLogger.error('main.fatal', e, s);
    runApp(_FatalErrorApp(error: e));
  }
}

Future<void> _bootstrapAndRun() async {
  await AppLogger.init();

  // 桌面平台（macOS/Windows/Linux）sqflite 不支持插件通道，改用 FFI 实现；
  // 数据库落盘路径由 AppDatabase.resolveDatabasePath 统一为绝对路径
  // （FFI 的 getDatabasesPath 兜底按 cwd 解析，Finder 启动时 cwd=/ 会失败）。
  if (!kIsWeb &&
      (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final sysLocale = PlatformDispatcher.instance.locale;
  // 互不依赖的初始化并行执行：冷启动耗时 = 最慢一项而非串行之和
  final prefsF = SharedPreferences.getInstance();
  final appDbF = AppDatabase.open();
  final notifL10nF = _loadNotifL10n(sysLocale);
  final prefs = await prefsF;
  final appDb = await appDbF;
  final notifL10n = await notifL10nF;
  final settings = SyncSettings(prefs, SecureCredentialStore());
  await settings.load();
  await settings.migrateLegacyPrefs();
  final localBackup = LocalBackupManager(appDb: appDb, prefs: prefs);
  final taskRepo = TaskRepository(appDb);
  final syncManager = SyncManager(
    appDb: appDb,
    taskRepository: taskRepo,
    settings: settings,
  );
  syncManager.refreshClient();
  // 通知文案跟随系统语言（否则回退中文）
  final notifications = NotificationService(l10n: notifL10n);
  // 冷启动通知跳转依赖 init 完成（读 initialTaskId），权限申请移到首帧之后
  try {
    await notifications.init();
  } catch (e) {
    AppLogger.warn('main.initNotifications', '$e');
  }

  // 点击通知 → 跳转对应任务详情
  void openTaskFromNotification(int taskId) {
    appNavigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: taskId)),
    );
  }

  notifications.onNotificationTap = openTaskFromNotification;
  final launchTaskId = notifications.initialTaskId;

  // 显式创建容器：同步落库回调需要在 Widget 树之外读 provider 刷新视图
  final container = ProviderContainer(overrides: [
    appDbProvider.overrideWithValue(appDb),
    syncSettingsProvider.overrideWithValue(settings),
    syncManagerProvider.overrideWithValue(syncManager),
    notificationServiceProvider.overrideWithValue(notifications),
    localBackupProvider.overrideWithValue(localBackup),
  ]);

  // 同步快照落库后：重排本机通知（其他设备新建的提醒要响、
  // 另一端完成/删除的要取消）+ 刷新视图（下载的变更否则不可见）
  syncManager.onSnapshotApplied = () {
    unawaitedSync(notifications.rescheduleAllFromDb(appDb));
    container.read(taskMutationProvider.notifier).state++;
  };

  runApp(UncontrolledProviderScope(
    container: container,
    child: TickTodoApp(
      initialTaskId: launchTaskId,
      onOpenTask: openTaskFromNotification,
    ),
  ));

  // 打开 App 自动同步（不阻塞启动）
  unawaitedSync(syncManager.syncNow());
  // 通知权限弹窗不阻塞首帧，首帧后再请求
  unawaitedSync(notifications.requestPermissions());
  // 自动本地备份（超 24h 才执行）
  unawaitedSync(localBackup.autoBackupIfDue());
  // 自动清理超过墓碑保留期的软删数据（任务/习惯/打卡/番茄会话）
  final retentionMs = kTombstoneRetention.inMilliseconds;
  unawaitedSync(taskRepo.purgeDeleted(olderThanMs: retentionMs));
  unawaitedSync(HabitRepository(appDb).purgeDeleted(olderThanMs: retentionMs));
  unawaitedSync(PomodoroRepository(appDb).purgeDeleted(olderThanMs: retentionMs));
}

/// 通知频道文案的本地化源；失败回退中文。
Future<AppLocalizations?> _loadNotifL10n(Locale locale) async {
  try {
    return await AppLocalizations.delegate.load(locale);
  } catch (_) {
    return null;
  }
}

void unawaitedSync(Future<void> f) {
  f.then((_) {}, onError: (_) {});
}

/// 启动失败的可见兜底页（避免"进程活着但永远黑屏"的静默故障）。
class _FatalErrorApp extends StatelessWidget {
  const _FatalErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 16),
                const Text(
                  '启动失败',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                const Text(
                  '请重新打开应用；若持续失败请查看日志（文档目录 logs/app.log）并反馈。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
