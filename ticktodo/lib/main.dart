import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ticktodo/app.dart';
import 'package:ticktodo/backup/local_backup.dart';
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
  await AppLogger.init();

  // 桌面平台（macOS/Windows/Linux）sqflite 不支持插件通道，改用 FFI 实现
  if (!kIsWeb &&
      (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final prefs = await SharedPreferences.getInstance();
  final settings = SyncSettings(prefs, SecureCredentialStore());
  await settings.load();
  await settings.migrateLegacyPrefs();
  final appDb = await AppDatabase.open();
  final localBackup = LocalBackupManager(appDb: appDb, prefs: prefs);
  final taskRepo = TaskRepository(appDb);
  final syncManager = SyncManager(
    appDb: appDb,
    taskRepository: taskRepo,
    settings: settings,
  );
  syncManager.refreshClient();
  // 通知文案跟随系统语言（否则回退中文）
  final sysLocale = PlatformDispatcher.instance.locale;
  AppLocalizations? notifL10n;
  try {
    notifL10n = await AppLocalizations.delegate.load(sysLocale);
  } catch (_) {
    notifL10n = null;
  }
  final notifications = NotificationService(l10n: notifL10n);
  try {
    await notifications.init();
    await notifications.requestPermissions();
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

  runApp(ProviderScope(
    overrides: [
      appDbProvider.overrideWithValue(appDb),
      syncSettingsProvider.overrideWithValue(settings),
      syncManagerProvider.overrideWithValue(syncManager),
      notificationServiceProvider.overrideWithValue(notifications),
      localBackupProvider.overrideWithValue(localBackup),
    ],
    child: TickTodoApp(
      initialTaskId: launchTaskId,
      onOpenTask: openTaskFromNotification,
    ),
  ));

  // 打开 App 自动同步（不阻塞启动）
  unawaitedSync(syncManager.syncNow());
  // 自动本地备份（超 24h 才执行）
  unawaitedSync(localBackup.autoBackupIfDue());
  // 自动清理回收站中删除超过 30 天的数据（任务/习惯/打卡/番茄会话）
  unawaitedSync(
      taskRepo.purgeDeleted(olderThanMs: 30 * 24 * 3600 * 1000));
  unawaitedSync(HabitRepository(appDb)
      .purgeDeleted(olderThanMs: 30 * 24 * 3600 * 1000));
  unawaitedSync(PomodoroRepository(appDb)
      .purgeDeleted(olderThanMs: 30 * 24 * 3600 * 1000));
}

void unawaitedSync(Future<void> f) {
  f.then((_) {}, onError: (_) {});
}
