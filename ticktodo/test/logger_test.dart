import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:ticktodo/core/logger.dart';

/// 测试用 path_provider 桩：返回临时目录，避免真实平台通道。
class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final Directory root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root.path;
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ticktodo_logger_test');
    PathProviderPlatform.instance = _FakePathProvider(root);
    AppLogger.enabled = true;
    await AppLogger.init();
  });

  tearDown(() async {
    AppLogger.enabled = true;
    AppLogger.resetForTest();
    await root.delete(recursive: true);
  });

  test('info/error 写入日志文件', () async {
    AppLogger.info('TestSrc', 'hello info');
    AppLogger.error('TestSrc', StateError('boom'));
    // 等待 fire-and-forget 写入完成
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final file = File(p.join(root.path, 'logs', 'app.log'));
    expect(await file.exists(), isTrue);
    final content = await file.readAsString();
    expect(content, contains('[INFO] [TestSrc] hello info'));
    expect(content, contains('[ERROR] [TestSrc] Bad state: boom'));
  });

  test('enabled=false 时不写文件', () async {
    AppLogger.enabled = false;
    AppLogger.info('TestSrc', 'should-not-write');

    final file = File(p.join(root.path, 'logs', 'app.log'));
    if (await file.exists()) {
      final content = await file.readAsString();
      expect(content, isNot(contains('should-not-write')));
    }
  });

  test('无 path_provider 时 init 静默失败不抛异常', () async {
    PathProviderPlatform.instance = _FakePathProvider(
        Directory('/nonexistent_${DateTime.now().microsecondsSinceEpoch}'));
    await AppLogger.init(); // 不应抛出
  });
}