import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/widget_bridge.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/list_model.dart';
import 'package:ticktodo/data/models/tag.dart';
import 'package:ticktodo/data/repositories/meta_repository.dart';
import 'package:ticktodo/data/repositories/task_repository.dart';
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
