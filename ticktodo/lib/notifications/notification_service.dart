import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:ticktodo/data/models/task.dart';

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  /// 点击通知回调（payload 为任务 id 字符串）。由 App 层注入导航逻辑。
  void Function(int taskId)? onNotificationTap;

  /// 冷启动：App 由点击通知拉起时携带的任务 id（init 后可读）。
  int? get initialTaskId => _initialTaskId;
  int? _initialTaskId;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // 时区获取失败时保持 UTC，不影响功能
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, macOS: darwin);
    await _plugin.initialize(settings,
        onDidReceiveNotificationResponse: _onResponse);
    _initialized = true;

    // 冷启动场景：App 未运行时点通知拉起
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _initialTaskId = _parsePayload(launch?.notificationResponse?.payload);
      }
    } catch (_) {}
  }

  void _onResponse(NotificationResponse resp) {
    final taskId = _parsePayload(resp.payload);
    if (taskId != null) onNotificationTap?.call(taskId);
  }

  int? _parsePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    return int.tryParse(payload);
  }

  Future<void> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    // iOS / macOS：弹窗申请提醒权限
    final mac = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    await mac?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// 调度任务提醒；remindAt 已过则取消并返回 false。
  Future<bool> scheduleReminder(Task task) async {
    final remindAt = task.remindAt;
    if (remindAt == null || task.id == null) return false;
    if (remindAt <= DateTime.now().millisecondsSinceEpoch) return false;

    final when = _tzDateTime(remindAt);
    try {
      await _plugin.zonedSchedule(
        task.id!,
        task.title,
        task.note.isEmpty ? '点击查看任务详情' : task.note,
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders',
            '任务提醒',
            channelDescription: '任务到期/提醒通知',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: '${task.id}',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> cancelReminder(int taskId) async {
    try {
      await _plugin.cancel(taskId);
      // 同时取消该任务的额外提醒槽位
      final base = taskId * _extraIdStride;
      for (var i = 0; i < _maxExtraPerTask; i++) {
        await _plugin.cancel(base + i);
      }
    } catch (_) {
      // 未初始化（测试环境）/平台异常时静默
    }
  }

  static const int _extraIdStride = 1000;
  static const int _maxExtraPerTask = 50;

  /// 调度一组额外提醒时间（通知 id = taskId * stride + 序号）。
  Future<void> scheduleExtraReminders({
    required int taskId,
    required String title,
    required String note,
    required List<int> epochs,
  }) async {
    final base = taskId * _extraIdStride;
    for (var i = 0; i < epochs.length && i < _maxExtraPerTask; i++) {
      final at = epochs[i];
      if (at <= DateTime.now().millisecondsSinceEpoch) continue;
      try {
        await _plugin.zonedSchedule(
          base + i,
          title,
          note,
          _tzDateTime(at),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'task_reminders',
              '任务提醒',
              channelDescription: '任务到期/提醒通知',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: '$taskId',
        );
      } catch (_) {}
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  tz.TZDateTime _tzDateTime(int ms) {
    try {
      return tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, ms);
    } catch (_) {
      return tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, ms);
    }
  }
}
