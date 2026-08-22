import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/widget_bridge.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/list_model.dart';
import 'package:ticktodo/data/models/tag.dart';
import 'package:ticktodo/data/repositories/meta_repository.dart';
import 'package:ticktodo/data/repositories/task_repository.dart';
import 'package:ticktodo/data/repositories/filter_repository.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/notifications/notification_service.dart';
import 'package:ticktodo/sync/sync_manager.dart';
import 'package:ticktodo/sync/sync_settings.dart';

/// 应用级服务（main 中初始化后 override）
final appDbProvider = Provider<AppDatabase>((ref) => throw UnimplementedError());
final taskRepoProvider = Provider<TaskRepository>(
    (ref) => TaskRepository(ref.watch(appDbProvider)));
final metaRepoProvider =
    Provider<MetaRepository>((ref) => MetaRepository(ref.watch(appDbProvider)));
final filterRepoProvider = Provider<FilterRepository>(
    (ref) => FilterRepository(ref.watch(appDbProvider)));
final syncSettingsProvider = Provider<SyncSettings>(
    (ref) => throw UnimplementedError());
final syncManagerProvider = Provider<SyncManager>(
    (ref) => throw UnimplementedError());
final notificationServiceProvider = Provider<NotificationService>(
    (ref) => throw UnimplementedError());

/// 数据变更计数：任何写操作后 +1，视图监听它自动刷新。
final taskMutationProvider = StateProvider<int>((ref) => 0);

void bumpMutation(WidgetRef ref) {
  ref.read(taskMutationProvider.notifier).state++;
  ref.read(syncManagerProvider).scheduleAutoUpload();
  refreshWidget();
}

/// 统一勾选入口：重复任务完成时生成下一期并重调度提醒；
/// 其余走普通切换。普通路径不触碰通知服务。
Future<void> toggleTaskWithRepeat(WidgetRef ref, Task t) async {
  final repo = ref.read(taskRepoProvider);
  if (!t.completed && t.repeatRule != null && t.dueDate != null) {
    final notifications = ref.read(notificationServiceProvider);
    final next = await repo.completeAndAdvance(t.id!);
    await notifications.cancelReminder(t.id!); // 同时清额外提醒槽位
    if (next != null) {
      if (next.remindAt != null) {
        await notifications.scheduleReminder(next);
      }
      final extras = await repo.queryRemindersOf(next.id!);
      if (extras.isNotEmpty) {
        await notifications.scheduleExtraReminders(
          taskId: next.id!,
          title: next.title,
          note: next.note,
          epochs: extras.map((e) => e.remindAt).toList(),
        );
      }
    }
  } else {
    await repo.toggleComplete(t.id!, !t.completed);
    // 完成后取消额外提醒；取消完成则恢复调度
    final notifications = ref.read(notificationServiceProvider);
    if (t.id != null) {
      await notifications.cancelReminder(t.id!);
      if (!t.completed) {
        final fresh = await repo.getTask(t.id!);
        if (fresh?.remindAt != null) {
          await notifications.scheduleReminder(fresh!);
        }
        final extras = await repo.queryRemindersOf(t.id!);
        if (extras.isNotEmpty && fresh != null) {
          await notifications.scheduleExtraReminders(
            taskId: t.id!,
            title: fresh.title,
            note: fresh.note,
            epochs: extras.map((e) => e.remindAt).toList(),
          );
        }
      }
    }
  }
  bumpMutation(ref);
}

/// 主题模式（跟随系统/浅/深）
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// 清单/标签列表（变更时刷新）
final listsProvider = FutureProvider<List<ListModel>>((ref) async {
  ref.watch(taskMutationProvider);
  return ref.read(metaRepoProvider).queryLists();
});

final tagsProvider = FutureProvider<List<Tag>>((ref) async {
  ref.watch(taskMutationProvider);
  return ref.read(metaRepoProvider).queryTags();
});
