import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/widget_bridge.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/list_model.dart';
import 'package:ticktodo/data/models/tag.dart';
import 'package:ticktodo/data/repositories/meta_repository.dart';
import 'package:ticktodo/data/repositories/task_repository.dart';
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
    await notifications.cancelReminder(t.id!);
    if (next != null && next.remindAt != null) {
      await notifications.scheduleReminder(next);
    }
  } else {
    await repo.toggleComplete(t.id!, !t.completed);
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
