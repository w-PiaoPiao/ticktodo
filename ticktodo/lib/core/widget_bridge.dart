import 'package:flutter/services.dart';
import 'package:ticktodo/core/logger.dart';

/// 与原生侧（MainActivity）的通道：小部件刷新 + 启动日期。
const MethodChannel _channel = MethodChannel('ticktodo/widget');

/// 通知原生刷新桌面小部件（任务变更后调用）。
Future<void> refreshWidget() async {
  try {
    await _channel.invokeMethod('refreshWidget');
  } catch (e) {
    // 非 Android / 测试环境静默
    AppLogger.warn('widget_bridge.refreshWidget', '$e');
  }
}

/// 读取小部件点击传递的日期（yyyy-MM-dd），无则 null。
Future<String?> getStartupDate() async {
  try {
    final v = await _channel.invokeMethod<String>('getStartupDate');
    return v;
  } catch (e) {
    AppLogger.warn('widget_bridge.getStartupDate', '$e');
    return null;
  }
}
