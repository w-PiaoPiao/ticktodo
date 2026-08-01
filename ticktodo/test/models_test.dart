import 'package:flutter_test/flutter_test.dart';
import 'package:ticktodo/data/models/list_model.dart';
import 'package:ticktodo/data/models/subtask.dart';
import 'package:ticktodo/data/models/tag.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/data/models/task_tag_link.dart';

void main() {
  group('Task', () {
    test('toMap/fromMap 往返一致', () {
      final t = Task(
        id: 1,
        title: '买牛奶',
        note: '记得打折',
        completed: true,
        priority: TaskPriority.high,
        dueDate: '2026-08-01',
        dueTime: '09:30',
        remindAt: 1754015400000,
        listId: 3,
        sortOrder: 5,
        createdAt: 100,
        updatedAt: 200,
        deletedAt: null,
      );
      final round = Task.fromMap(t.toMap());
      expect(round.id, 1);
      expect(round.title, '买牛奶');
      expect(round.note, '记得打折');
      expect(round.completed, true);
      expect(round.priority, TaskPriority.high);
      expect(round.dueDate, '2026-08-01');
      expect(round.dueTime, '09:30');
      expect(round.remindAt, 1754015400000);
      expect(round.listId, 3);
      expect(round.sortOrder, 5);
      expect(round.updatedAt, 200);
      expect(round.isDeleted, false);
    });

    test('null 字段默认值', () {
      final t = Task.fromMap({
        'id': null,
        'title': null,
        'completed': null,
        'priority': null,
        'listId': null,
      });
      expect(t.title, '');
      expect(t.completed, false);
      expect(t.priority, TaskPriority.none);
      expect(t.listId, 0);
    });

    test('copyWith clear 语义', () {
      final t = Task(
          title: 'x', dueDate: '2026-08-01', dueTime: '10:00', remindAt: 1, listId: 1);
      final c = t.copyWith(clearDueDate: true, clearRemindAt: true);
      expect(c.dueDate, null);
      expect(c.dueTime, '10:00');
      expect(c.remindAt, null);
    });

    test('deletedAt 软删除标记', () {
      final t = Task(title: 'x', deletedAt: 999, listId: 1);
      expect(t.isDeleted, true);
    });
  });

  group('TaskPriority', () {
    test('枚举值', () {
      expect(TaskPriority.none.value, 0);
      expect(TaskPriority.low.value, 1);
      expect(TaskPriority.medium.value, 2);
      expect(TaskPriority.high.value, 3);
      expect(TaskPriority.high.label, '高');
    });
    test('fromValue 未知值回退 none', () {
      expect(TaskPriority.fromValue(99), TaskPriority.none);
      expect(TaskPriority.fromValue(2), TaskPriority.medium);
    });
  });

  group('ListModel', () {
    test('往返一致 + 软删除', () {
      final l = ListModel(
        id: 2,
        name: '工作',
        color: 0xFF123456,
        icon: 1,
        sortOrder: 3,
        isDefault: true,
        createdAt: 10,
        updatedAt: 20,
      );
      final r = ListModel.fromMap(l.toMap());
      expect(r.id, 2);
      expect(r.name, '工作');
      expect(r.color, 0xFF123456);
      expect(r.isDefault, true);
      expect(r.isDeleted, false);
      expect(l.copyWith(deletedAt: 30).isDeleted, true);
    });
  });

  group('Tag', () {
    test('往返一致', () {
      final t = Tag(id: 1, name: '健身', color: 0xFFFF0000, updatedAt: 5);
      final r = Tag.fromMap(t.toMap());
      expect(r.name, '健身');
      expect(r.color, 0xFFFF0000);
      expect(r.updatedAt, 5);
    });
  });

  group('Subtask', () {
    test('往返一致', () {
      final s = Subtask(
          id: 1,
          taskId: 9,
          title: '准备材料',
          completed: true,
          sortOrder: 2,
          updatedAt: 7);
      final r = Subtask.fromMap(s.toMap());
      expect(r.taskId, 9);
      expect(r.title, '准备材料');
      expect(r.completed, true);
      expect(r.sortOrder, 2);
    });
  });

  group('TaskTagLink', () {
    test('往返一致与相等', () {
      final a = TaskTagLink(taskId: 1, tagId: 2);
      final b = TaskTagLink.fromMap(a.toMap());
      expect(b, a);
      expect(a == TaskTagLink(taskId: 1, tagId: 3), false);
    });
  });
}
