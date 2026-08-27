import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 轻量文件日志：写应用文档目录 logs/app.log（超 1MB 滚动重建），
/// 同时 debugPrint 镜像到控制台。
///
/// - 不阻塞调用方：文件写入 fire-and-forget
/// - 测试环境可设 [enabled] = false（widget 测试无 path_provider 通道）
/// - 所有写失败静默吞掉，不影响业务
class AppLogger {
  AppLogger._();

  /// 测试/产物环境可关闭（默认 true）。
  static bool enabled = true;

  static File? _file;
  static int _bytes = 0;
  static const int _maxBytes = 1024 * 1024;

  /// 串行写入链：避免并发 fire-and-forget 写同一文件互相覆盖。
  static Future<void> _writeChain = Future<void>.value();

  /// 启动时调用一次；失败静默（仅控制台仍可用）。
  static Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logDir = Directory(p.join(dir.path, 'logs'));
      await logDir.create(recursive: true);
      final file = File(p.join(logDir.path, 'app.log'));
      if (await file.exists()) _bytes = await file.length();
      _file = file;
    } catch (_) {
      // path_provider 不可用（测试等），仅保留控制台输出
    }
  }

  static void info(String source, String message) =>
      _write('INFO', source, message);

  static void warn(String source, String message) =>
      _write('WARN', source, message);

  static void error(String source, Object error, [StackTrace? stack]) {
    final msg = stack == null ? '$error' : '$error\n$stack';
    _write('ERROR', source, msg);
  }

  static void _write(String level, String source, String message) {
    if (!enabled) return;
    debugPrint('[$level] $source: $message');
    final f = _file;
    if (f == null) return;
    final line = '[${DateTime.now().toIso8601String()}] '
        '[$level] [$source] $message\n';
    _writeChain = _writeChain.then((_) => _append(f, line));
    unawaited(_writeChain);
  }

  /// 测试用：重置内部状态（清理 _file 引用）。
  static void resetForTest() {
    _file = null;
    _bytes = 0;
    _writeChain = Future<void>.value();
  }

  static Future<void> _append(File f, String line) async {
    try {
      if (_bytes + line.codeUnits.length > _maxBytes) {
        await f.writeAsString(line, flush: true);
        _bytes = line.codeUnits.length;
      } else {
        await f.writeAsString(line, mode: FileMode.append, flush: true);
        _bytes += line.codeUnits.length;
      }
    } catch (_) {}
  }
}