import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ticktodo/app.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/repositories/task_repository.dart';
import 'package:ticktodo/notifications/notification_service.dart';
import 'package:ticktodo/sync/sync_manager.dart';
import 'package:ticktodo/sync/sync_settings.dart';

/// 端到端冒烟：真机/模拟器上完成 新建→勾选→删除 全流程
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('端到端：新建任务 → 勾选完成 → 删除', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final settings = SyncSettings(prefs);
    final appDb = await AppDatabase.open();
    final taskRepo = TaskRepository(appDb);
    final syncManager = SyncManager(
      appDb: appDb,
      taskRepository: taskRepo,
      settings: settings,
    );
    final notifications = NotificationService();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDbProvider.overrideWithValue(appDb),
        syncSettingsProvider.overrideWithValue(settings),
        syncManagerProvider.overrideWithValue(syncManager),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: const TickTodoApp(),
    ));
    await tester.pump(const Duration(seconds: 2));

    // 新建任务
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(
        find.widgetWithText(TextField, '任务标题'), '端到端测试任务');
    await tester.pump(const Duration(milliseconds: 400));

    // 返回列表
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 1));

    // 今天视图应出现任务（无日期默认今天）
    expect(find.text('端到端测试任务'), findsOneWidget);

    // 勾选完成
    final check = find.byKey(const ValueKey('check-1'));
    await tester.tap(check);
    await tester.pump(const Duration(seconds: 1));
    // 勾选后仍在列表中（已完成区）
    expect(find.text('端到端测试任务'), findsOneWidget);

    // 打开详情删除
    await tester.tap(find.text('端到端测试任务'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('任务详情'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('删除'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('任务详情'), findsNothing);
  });
}
