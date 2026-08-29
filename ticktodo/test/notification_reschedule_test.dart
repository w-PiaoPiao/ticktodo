import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/notifications/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;

class _MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class _FakeTZDateTime extends Fake implements tz.TZDateTime {}

class _FakeNotificationDetails extends Fake implements NotificationDetails {}

void main() {
  late AppDatabase appDb;
  late _MockPlugin plugin;
  late NotificationService service;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // mocktail 对非基础类型参数要求先注册 fallback
    registerFallbackValue(_FakeTZDateTime());
    registerFallbackValue(_FakeNotificationDetails());
    registerFallbackValue(UILocalNotificationDateInterpretation.absoluteTime);
    registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
    registerFallbackValue(DateTimeComponents.time);
  });

  setUp(() async {
    appDb = await AppDatabase.open(inMemoryPath: inMemoryDatabasePath);
    plugin = _MockPlugin();
    service = NotificationService(plugin: plugin);
    when(() => plugin.cancel(any(), tag: any(named: 'tag')))
        .thenAnswer((_) async {});
    when(() => plugin.zonedSchedule(
          any(),
          any(),
          any(),
          any(),
          any(),
          uiLocalNotificationDateInterpretation:
              any(named: 'uiLocalNotificationDateInterpretation'),
          androidScheduleMode: any(named: 'androidScheduleMode'),
          payload: any(named: 'payload'),
          matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
        )).thenAnswer((_) async {});
  });

  tearDown(() async {
    await appDb.db.close();
  });

  Future<void> insertTask(Map<String, Object?> extra) async {
    await appDb.db.insert('tasks', {
      'title': 't',
      'listId': 1,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'completed': 0,
      ...extra,
    });
  }

  void verifyScheduled(int id) => verify(() => plugin.zonedSchedule(
        id,
        any(),
        any(),
        any(),
        any(),
        uiLocalNotificationDateInterpretation:
            any(named: 'uiLocalNotificationDateInterpretation'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        payload: any(named: 'payload'),
        matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
      ));

  void verifyNeverScheduled(int id) => verifyNever(() => plugin.zonedSchedule(
        id,
        any(),
        any(),
        any(),
        any(),
        uiLocalNotificationDateInterpretation:
            any(named: 'uiLocalNotificationDateInterpretation'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        payload: any(named: 'payload'),
        matchDateTimeComponents: any(named: 'matchDateTimeComponents'),
      ));

  test('活跃任务的未来主提醒被重排', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await insertTask({'id': 1, 'remindAt': now + 3600000});
    await service.rescheduleAllFromDb(appDb);

    verify(() => plugin.cancel(1, tag: any(named: 'tag')));
    verifyScheduled(1);
  });

  test('过期主提醒只取消不重排', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await insertTask({'id': 2, 'remindAt': now - 1000});
    await service.rescheduleAllFromDb(appDb);

    verify(() => plugin.cancel(2, tag: any(named: 'tag')));
    verifyNeverScheduled(2);
  });

  test('已完成/已删除任务取消遗留调度且不重排（含其额外提醒）', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await insertTask({'id': 3, 'remindAt': now + 3600000, 'completed': 1});
    await appDb.db.insert('reminders', {
      'taskId': 3,
      'remindAt': now + 7200000,
      'updatedAt': now,
    });
    await insertTask({'id': 4, 'remindAt': now + 3600000, 'deletedAt': now});
    await service.rescheduleAllFromDb(appDb);

    verify(() => plugin.cancel(3, tag: any(named: 'tag')));
    verify(() => plugin.cancel(4, tag: any(named: 'tag')));
    verifyNeverScheduled(3);
    verifyNeverScheduled(3 * 1000);
    verifyNeverScheduled(4);
  });

  test('无提醒任务完全不触碰', () async {
    await insertTask({'id': 5});
    await service.rescheduleAllFromDb(appDb);

    verifyNever(() => plugin.cancel(5, tag: any(named: 'tag')));
  });

  test('额外提醒（reminders 表）按槽位 id 重排', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await insertTask({'id': 6});
    await appDb.db.insert('reminders', {
      'taskId': 6,
      'remindAt': now + 3600000,
      'updatedAt': now,
    });
    await appDb.db.insert('reminders', {
      'taskId': 6,
      'remindAt': now - 1000, // 已过期 → 跳过
      'updatedAt': now,
    });
    await service.rescheduleAllFromDb(appDb);

    verifyScheduled(6 * 1000);
    verifyNeverScheduled(6 * 1000 + 1);
    verify(() => plugin.cancel(6, tag: any(named: 'tag')));
  });
}
