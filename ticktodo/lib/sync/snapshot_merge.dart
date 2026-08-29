import 'package:ticktodo/data/models/filter.dart';
import 'package:ticktodo/data/models/habit.dart';
import 'package:ticktodo/data/models/list_model.dart';
import 'package:ticktodo/data/models/reminder.dart';
import 'package:ticktodo/data/models/subtask.dart';
import 'package:ticktodo/data/models/tag.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/data/models/task_tag_link.dart';
import 'package:ticktodo/sync/snapshot.dart';

/// 按 id 合并两条快照：每条记录取 updatedAt 较新者；同 updatedAt 取 remote（确定性）。
/// revision 取两者较大值。
SyncSnapshot mergeSnapshots(SyncSnapshot local, SyncSnapshot remote) {
  final tasks = _mergeById<Task>(local.tasks, remote.tasks,
      (a, b) => (a.updatedAt ?? 0) >= (b.updatedAt ?? 0) ? a : b);
  final subtasks = _mergeById<Subtask>(local.subtasks, remote.subtasks,
      (a, b) => (a.updatedAt ?? 0) >= (b.updatedAt ?? 0) ? a : b);
  final lists = _mergeById<ListModel>(local.lists, remote.lists,
      (a, b) => (a.updatedAt ?? 0) >= (b.updatedAt ?? 0) ? a : b);
  final tags = _mergeById<Tag>(local.tags, remote.tags,
      (a, b) => (a.updatedAt ?? 0) >= (b.updatedAt ?? 0) ? a : b);
  final taskTags = _mergeLinks(local.taskTags, remote.taskTags);
  final reminders =
      _mergeById<Reminder>(local.reminders, remote.reminders, pickNewer);
  final filters =
      _mergeById<Filter>(local.filters, remote.filters, pickNewer);
  final habits =
      _mergeById<Habit>(local.habits, remote.habits, pickNewer);
  final habitChecks =
      _mergeById<HabitCheck>(local.habitChecks, remote.habitChecks, pickNewer);
  final pomodoros =
      _mergeById<PomodoroSession>(local.pomodoros, remote.pomodoros, pickNewer);
  return SyncSnapshot(
    revision: local.revision > remote.revision ? local.revision : remote.revision,
    tasks: tasks,
    subtasks: subtasks,
    lists: lists,
    tags: tags,
    taskTags: taskTags,
    reminders: reminders,
    filters: filters,
    habits: habits,
    habitChecks: habitChecks,
    pomodoros: pomodoros,
  );
}

T pickNewer<T>(T a, T b) => _updatedAtOf(a) >= _updatedAtOf(b) ? a : b;

int _updatedAtOf(dynamic item) {
  if (item is Habit) return item.updatedAt ?? 0;
  if (item is HabitCheck) return item.updatedAt ?? 0;
  if (item is PomodoroSession) return item.updatedAt ?? 0;
  if (item is Task) return item.updatedAt ?? 0;
  if (item is Subtask) return item.updatedAt ?? 0;
  if (item is ListModel) return item.updatedAt ?? 0;
  if (item is Tag) return item.updatedAt ?? 0;
  if (item is Reminder) return item.updatedAt ?? 0;
  if (item is Filter) return item.updatedAt ?? 0;
  return 0;
}

List<T> _mergeById<T>(List<T> local, List<T> remote, T Function(T a, T b) pick) {
  final byId = <int, T>{};
  for (final item in local) {
    final id = _idOf(item);
    if (id != null) byId[id] = item;
  }
  for (final item in remote) {
    final id = _idOf(item);
    if (id == null) continue;
    final existing = byId[id];
    byId[id] = existing == null ? item : pick(existing, item);
  }
  final result = byId.values.toList();
  result.sort((a, b) => (_idOf(a) ?? 0).compareTo(_idOf(b) ?? 0));
  return result;
}

int? _idOf(dynamic item) {
  if (item is Habit) return item.id;
  if (item is HabitCheck) return item.id;
  if (item is PomodoroSession) return item.id;
  if (item is Reminder) return item.id;
  if (item is Filter) return item.id;
  if (item is Task) return item.id;
  if (item is Subtask) return item.id;
  if (item is ListModel) return item.id;
  if (item is Tag) return item.id;
  return null;
}

/// task_tags 按关联对 (taskId, tagId) 做 LWW：墓碑行（deletedAt 非空）与
/// 正常行同台比较 updatedAt，"取消标签"才能作为事件同步到其他设备；
/// 重新添加时 updatedAt 更新，自然胜过旧墓碑。
List<TaskTagLink> _mergeLinks(List<TaskTagLink> local, List<TaskTagLink> remote) {
  TaskTagLink pick(TaskTagLink a, TaskTagLink b) =>
      (a.updatedAt ?? 0) >= (b.updatedAt ?? 0) ? a : b;
  final byPair = <String, TaskTagLink>{};
  void put(TaskTagLink l) {
    final key = '${l.taskId}:${l.tagId}';
    final existing = byPair[key];
    byPair[key] = existing == null ? l : pick(existing, l);
  }

  for (final l in local) {
    put(l);
  }
  for (final l in remote) {
    put(l);
  }
  final list = byPair.values.toList();
  list.sort((a, b) =>
      a.taskId != b.taskId ? a.taskId.compareTo(b.taskId) : a.tagId.compareTo(b.tagId));
  return list;
}
