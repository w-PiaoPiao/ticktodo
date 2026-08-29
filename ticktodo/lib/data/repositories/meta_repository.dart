import 'package:sqflite/sqflite.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/list_model.dart';
import 'package:ticktodo/data/models/tag.dart';
import 'package:ticktodo/data/models/task_tag_link.dart';

class MetaRepository {
  MetaRepository(this._appDb);

  final AppDatabase _appDb;
  Database get db => _appDb.db;

  int _now() => DateTime.now().millisecondsSinceEpoch;

  // ---------- 清单 ----------

  Future<int?> upsertList(ListModel list) async {
    final now = _now();
    final l = list.copyWith(updatedAt: now, createdAt: list.createdAt ?? now);
    if (l.id == null) {
      final id = await db.insert('lists', l.toMap()..remove('id'));
      return id;
    }
    await db.update('lists', l.toMap(), where: 'id = ?', whereArgs: [l.id]);
    return l.id;
  }

  Future<void> bulkUpsertLists(List<ListModel> lists) async {
    final now = _now();
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final list in lists) {
        final l =
            list.copyWith(updatedAt: now, createdAt: list.createdAt ?? now);
        if (l.id == null) {
          batch.insert('lists', l.toMap()..remove('id'));
        } else {
          batch.insert('lists', l.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> softDeleteList(int id) async {
    final now = _now();
    await db.update('lists', {'deletedAt': now, 'updatedAt': now},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ListModel>> queryLists() async {
    final rows = await db.query('lists',
        where: 'deletedAt IS NULL',
        orderBy: 'isPinned DESC, sortOrder ASC, id ASC');
    return rows.map(ListModel.fromMap).toList();
  }

  Future<ListModel?> getList(int id) async {
    final rows = await db.query('lists', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return ListModel.fromMap(rows.first);
  }

  /// 默认清单（无则返回 null，由调用方兜底建"收集箱"）
  Future<ListModel?> getDefaultList() async {
    final rows = await db.query('lists',
        where: 'isDefault = 1 AND deletedAt IS NULL', limit: 1);
    if (rows.isEmpty) return null;
    return ListModel.fromMap(rows.first);
  }

  /// 确保存在默认清单，不存在则创建"收集箱"。
  Future<int> ensureDefaultList() async {
    final existing = await getDefaultList();
    if (existing != null) return existing.id!;
    final id = await upsertList(const ListModel(name: '收集箱', isDefault: true));
    return id!;
  }

  // ---------- 标签 ----------

  Future<int?> upsertTag(Tag tag) async {
    final now = _now();
    final t = tag.copyWith(updatedAt: now, createdAt: tag.createdAt ?? now);
    if (t.id == null) {
      final id = await db.insert('tags', t.toMap()..remove('id'));
      return id;
    }
    await db.update('tags', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
    return t.id;
  }

  Future<void> bulkUpsertTags(List<Tag> tags) async {
    final now = _now();
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final tag in tags) {
        final t = tag.copyWith(updatedAt: now, createdAt: tag.createdAt ?? now);
        if (t.id == null) {
          batch.insert('tags', t.toMap()..remove('id'));
        } else {
          batch.insert('tags', t.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> softDeleteTag(int id) async {
    final now = _now();
    await db.transaction((txn) async {
      await txn.update('tags', {'deletedAt': now, 'updatedAt': now},
          where: 'id = ?', whereArgs: [id]);
      // 关联一并软删留墓碑：硬删行经同步合并会被远端复活
      await txn.update('task_tags', {'deletedAt': now, 'updatedAt': now},
          where: 'tagId = ? AND deletedAt IS NULL', whereArgs: [id]);
    });
  }

  Future<List<Tag>> queryTags() async {
    final rows = await db.query('tags',
        where: 'deletedAt IS NULL', orderBy: 'name ASC');
    return rows.map(Tag.fromMap).toList();
  }

  // ---------- 任务-标签关联 ----------

  Future<void> linkTaskTag(int taskId, int tagId) async {
    // 带 updatedAt 且不带 deletedAt：重新添加要能胜过旧墓碑（LWW 取新）
    await db.insert(
        'task_tags',
        TaskTagLink(taskId: taskId, tagId: tagId, updatedAt: _now()).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> unlinkTaskTag(int taskId, int tagId) async {
    // 软删留墓碑：取消标签要作为事件同步到其他设备
    final now = _now();
    final updated = await db.update('task_tags', {'deletedAt': now, 'updatedAt': now},
        where: 'taskId = ? AND tagId = ?', whereArgs: [taskId, tagId]);
    if (updated == 0) {
      // 本地没有该关联行：写入纯墓碑，保证删除事件仍可传播到远端
      await db.insert(
          'task_tags',
          TaskTagLink(taskId: taskId, tagId: tagId, updatedAt: now, deletedAt: now)
              .toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> setTaskTags(int taskId, List<int> tagIds) async {
    final now = _now();
    await db.transaction((txn) async {
      final existing = await txn.query('task_tags',
          columns: ['tagId'],
          where: 'taskId = ? AND deletedAt IS NULL',
          whereArgs: [taskId]);
      final removed = existing
          .map((r) => r['tagId'] as int)
          .where((id) => !tagIds.contains(id))
          .toList();
      for (final tagId in removed) {
        await txn.update('task_tags', {'deletedAt': now, 'updatedAt': now},
            where: 'taskId = ? AND tagId = ?', whereArgs: [taskId, tagId]);
      }
      for (final tagId in tagIds) {
        await txn.insert(
            'task_tags',
            TaskTagLink(taskId: taskId, tagId: tagId, updatedAt: now).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<int>> tagIdsOfTask(int taskId) async {
    final rows = await db.query('task_tags',
        where: 'taskId = ? AND deletedAt IS NULL', whereArgs: [taskId]);
    return rows.map((r) => r['tagId'] as int).toList();
  }

  Future<Map<int, List<int>>> allTaskTagLinks() async {
    final rows = await db.query('task_tags', where: 'deletedAt IS NULL');
    final map = <int, List<int>>{};
    for (final r in rows) {
      map.putIfAbsent(r['taskId'] as int, () => []).add(r['tagId'] as int);
    }
    return map;
  }
}
