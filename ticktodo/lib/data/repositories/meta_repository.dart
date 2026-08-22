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
      await txn.delete('task_tags', where: 'tagId = ?', whereArgs: [id]);
    });
  }

  Future<List<Tag>> queryTags() async {
    final rows = await db.query('tags',
        where: 'deletedAt IS NULL', orderBy: 'name ASC');
    return rows.map(Tag.fromMap).toList();
  }

  // ---------- 任务-标签关联 ----------

  Future<void> linkTaskTag(int taskId, int tagId) async {
    await db.insert('task_tags',
        TaskTagLink(taskId: taskId, tagId: tagId).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> unlinkTaskTag(int taskId, int tagId) async {
    await db.delete('task_tags',
        where: 'taskId = ? AND tagId = ?', whereArgs: [taskId, tagId]);
  }

  Future<void> setTaskTags(int taskId, List<int> tagIds) async {
    await db.transaction((txn) async {
      await txn.delete('task_tags', where: 'taskId = ?', whereArgs: [taskId]);
      final batch = txn.batch();
      for (final tagId in tagIds) {
        batch.insert(
            'task_tags', TaskTagLink(taskId: taskId, tagId: tagId).toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<int>> tagIdsOfTask(int taskId) async {
    final rows = await db.query('task_tags',
        where: 'taskId = ?', whereArgs: [taskId]);
    return rows.map((r) => r['tagId'] as int).toList();
  }

  Future<Map<int, List<int>>> allTaskTagLinks() async {
    final rows = await db.query('task_tags');
    final map = <int, List<int>>{};
    for (final r in rows) {
      map.putIfAbsent(r['taskId'] as int, () => []).add(r['tagId'] as int);
    }
    return map;
  }
}
