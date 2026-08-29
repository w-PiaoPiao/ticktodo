import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:ticktodo/core/logger.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/models/task.dart';
import 'package:ticktodo/l10n/app_localizations.dart';

class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin, AppLocalizations? l10n})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin(), // ignore: prefer_initializing_formals
        _l10n = l10n; // ignore: prefer_initializing_formals

  /// 通知频道名与正文的本地化源（main 中加载）。
  /// null 时使用中文回退（测试/未注入场景）。
  final AppLocalizations? _l10n;

  String _str(String zh, String Function(AppLocalizations) en) =>
      _l10n == null ? zh : en(_l10n);

  String get _taskChannelName =>
      _str('任务提醒', (l) => l.notifTaskChannel);

  String get _taskChannelDesc =>
      _str('任务到期/提醒通知', (l) => l.notifTaskChannelDesc);

  String get _pomodoroChannelName =>
      _str('番茄专注', (l) => l.notifPomodoroChannel);

  String get _pomodoroChannelDesc =>
      _str('专注/休息阶段切换提醒', (l) => l.notifPomodoroChannelDesc);

  String get _openTaskHint =>
      _str('点击查看任务详情', (l) => l.notifOpenTask);

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
    } catch (e) {
      // 时区获取失败时保持 UTC，不影响功能
      AppLogger.warn('NotificationService.init', '时区获取失败: $e');
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
    } catch (e) {
      AppLogger.warn('NotificationService.init', '读取冷启动通知失败: $e');
    }
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

  /// 精确闹钟调度：先尝试 exact（Doze 下到点即响），
  /// 无权限/平台不支持时回退 inexact（宁可延迟也不丢提醒）。
  Future<void> _zonedScheduleCompat({
    required int id,
    required String? title,
    required String? body,
    required tz.TZDateTime when,
    required NotificationDetails details,
    String? payload,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } on PlatformException {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
  }

  /// 调度任务提醒；remindAt 已过则取消并返回 false。
  Future<bool> scheduleReminder(Task task) async {
    final remindAt = task.remindAt;
    if (remindAt == null || task.id == null) return false;
    if (remindAt <= DateTime.now().millisecondsSinceEpoch) return false;

    final when = _tzDateTime(remindAt);
    try {
      await _zonedScheduleCompat(
        id: task.id!,
        title: task.title,
        body: task.note.isEmpty ? _openTaskHint : task.note,
        when: when,
        details: NotificationDetails(
          android: AndroidNotificationDetails(
            'task_reminders',
            _taskChannelName,
            channelDescription: _taskChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: '${task.id}',
      );
      return true;
    } catch (e) {
      AppLogger.error('NotificationService.scheduleReminder', e);
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
    } catch (e) {
      // 未初始化（测试环境）/平台异常时静默
      AppLogger.warn('NotificationService.cancelReminder', '$e');
    }
  }

  static const int _extraIdStride = 1000;
  static const int _maxExtraPerTask = 50;

  /// 番茄阶段通知专用 id：取值远超任务提醒 id 空间（taskId*1000+50），
  /// 避免任务数增长后撞车。
  static const int pomodoroNotificationId = 1900000001;

  NotificationDetails get _pomodoroDetails => NotificationDetails(
        android: AndroidNotificationDetails(
          'pomodoro',
          _pomodoroChannelName,
          channelDescription: _pomodoroChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
        macOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      );

  /// 调度番茄阶段结束通知（绝对时间，由系统触发）。
  ///
  /// 必须用 zonedSchedule 而非 Future.delayed：后者在移动端 App 挂起后
  /// 不执行，导致后台到点不通知；且暂停后 stale 回调会误报。
  Future<void> schedulePomodoroEnd({
    required String title,
    required String body,
    required DateTime at,
  }) async {
    try {
      await _zonedScheduleCompat(
        id: pomodoroNotificationId,
        title: title,
        body: body,
        when: _tzDateTime(at.millisecondsSinceEpoch),
        details: _pomodoroDetails,
      );
    } catch (e) {
      // 测试环境/平台异常静默
      AppLogger.warn('NotificationService.schedulePomodoroEnd', '$e');
    }
  }

  /// 取消番茄阶段结束通知（暂停/放弃/段切换时调用）。
  Future<void> cancelPomodoroNotification() async {
    try {
      await _plugin.cancel(pomodoroNotificationId);
    } catch (e) {
      AppLogger.warn('NotificationService.cancelPomodoro', '$e');
    }
  }

  /// 立即显示一条通知（即时提醒）。
  Future<void> showNow({
    required String title,
    required String body,
    required int id,
    String? payload,
  }) async {
    try {
      await _plugin.show(id, title, body, _pomodoroDetails, payload: payload);
    } catch (e) {
      // 测试环境/平台异常静默
      AppLogger.warn('NotificationService.showNow', '$e');
    }
  }

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
        await _zonedScheduleCompat(
          id: base + i,
          title: title,
          body: note,
          when: _tzDateTime(at),
          details: NotificationDetails(
            android: AndroidNotificationDetails(
              'task_reminders',
              _taskChannelName,
              channelDescription: _taskChannelDesc,
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          payload: '$taskId',
        );
      } catch (e) {
        AppLogger.warn('NotificationService.scheduleExtraReminders', '$e');
      }
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// 以数据库为准全量重排任务提醒（同步下载落库后调用）：
  /// 其他设备新建的提醒要能在本机响铃，另一端完成/删除的任务要取消本机遗留调度。
  /// 只动任务提醒 id 空间（taskId 与 taskId*1000+i），不碰番茄通知。
  Future<void> rescheduleAllFromDb(AppDatabase appDb) async {
    final db = appDb.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    // 圈定所有有提醒（主/额外）的任务，含已完成/已删除行——用于取消其遗留调度
    final taskRows = await db.rawQuery('''
      SELECT DISTINCT t.* FROM tasks t
      WHERE t.remindAt IS NOT NULL
         OR EXISTS (SELECT 1 FROM reminders r
                    WHERE r.taskId = t.id AND r.deletedAt IS NULL)
    ''');
    final extraRows = await db.query('reminders',
        where: 'deletedAt IS NULL AND remindAt > ?',
        whereArgs: [now],
        orderBy: 'remindAt ASC');
    final extrasByTask = <int, List<int>>{};
    for (final r in extraRows) {
      extrasByTask
          .putIfAbsent(r['taskId'] as int, () => [])
          .add(r['remindAt'] as int);
    }
    for (final row in taskRows) {
      final task = Task.fromMap(row);
      if (task.id == null) continue;
      // 先清掉本机现有调度（含额外槽位），再按库内当前状态重排
      await cancelReminder(task.id!);
      if (task.completed || task.isDeleted) continue;
      if (task.remindAt != null && task.remindAt! > now) {
        await scheduleReminder(task);
      }
      final epochs = extrasByTask[task.id];
      if (epochs != null && epochs.isNotEmpty) {
        await scheduleExtraReminders(
          taskId: task.id!,
          title: task.title,
          note: task.note,
          epochs: epochs,
        );
      }
    }
  }

  tz.TZDateTime _tzDateTime(int ms) {
    try {
      return tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, ms);
    } catch (e) {
      AppLogger.warn('NotificationService._tzDateTime', '$e');
      return tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, ms);
    }
  }
}
