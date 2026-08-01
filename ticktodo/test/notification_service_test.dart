import 'package:flutter_test/flutter_test.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/notifications/notification_service.dart';

void main() {
  test('remindAt 已过 → scheduleReminder 返回 false（不调度）', () async {
    final service = NotificationService();
    // 不 init，直接验证过期逻辑短路在插件调用之前
    final past = DateTime.now().millisecondsSinceEpoch - 1000;
    final task = TestTask(remindAt: past);
    expect(await service.scheduleReminder(task), false);
  });

  test('无 remindAt 或 id → 不调度', () async {
    final service = NotificationService();
    expect(await service.scheduleReminder(TestTask(remindAt: null)), false);
    expect(
        await service.scheduleReminder(
            TestTask(remindAt: DateTime.now().millisecondsSinceEpoch + 60000)),
        false);
  });
}

class TestTask extends Task {
  const TestTask({super.remindAt, super.id = 1})
      : super(title: '提醒测试', listId: 1);
}
