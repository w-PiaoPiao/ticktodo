import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:ticktodo/core/logger.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/repositories/task_repository.dart';
import 'package:ticktodo/sync/gzip_codec.dart';
import 'package:ticktodo/sync/snapshot.dart';
import 'package:ticktodo/sync/snapshot_merge.dart';
import 'package:ticktodo/sync/sync_settings.dart';
import 'package:ticktodo/sync/webdav_client.dart';

const String kBackupPath = 'TickTodo/todo_backup.json.gz';
const Duration kAutoUploadDebounce = Duration(seconds: 30);

class SyncResult {
  const SyncResult({
    this.didUpload = false,
    this.didDownload = false,
    this.merged = false,
    this.error,
  });

  final bool didUpload;
  final bool didDownload;
  final bool merged;
  final String? error;

  bool get success => error == null;
}

class SyncManager {
  // 参数名公开、字段私有，跨文件调用点（main/test 共 8 处）依赖命名参数，
  // 无法改用 this._x 形式参数，因此对构造器关闭该 lint。
  // ignore_for_file: prefer_initializing_formals
  SyncManager({
    required AppDatabase appDb,
    required TaskRepository taskRepository,
    required SyncSettings settings,
    WebDavClient? client,
  })  : _appDb = appDb,
        _taskRepository = taskRepository,
        _settings = settings,
        _client = client;

  final AppDatabase _appDb;
  final TaskRepository _taskRepository;
  final SyncSettings _settings;
  WebDavClient? _client;

  /// 快照真正写入本地库后回调（main 用于重排通知 + 刷新 UI）。
  /// main 里 container 与 SyncManager 相互依赖，因此用可赋值字段而非构造参数。
  void Function()? onSnapshotApplied;

  Timer? _debounce;
  bool _syncing = false;

  /// 最近一次同步结果/错误（UI 读取）。
  SyncResult? lastResult;

  WebDavClient? get client => _client;

  WebDavClient _createClient() {
    return WebDavClient(
      _settings.webdavUrl!,
      _settings.username!,
      _settings.password!,
    );
  }

  /// 凭据变化后重建 client。
  void refreshClient() {
    _client = _settings.hasCredentials ? _createClient() : null;
  }

  /// 打开 App 时调用：无凭据则跳过。
  Future<SyncResult> syncNow() async {
    if (!_settings.hasCredentials) {
      return const SyncResult();
    }
    if (_syncing) return lastResult ?? const SyncResult();
    _syncing = true;
    try {
      final c = _client ?? _createClient();
      final result = await _doSync(c);
      lastResult = result;
      if (result.success) {
        await _settings.setLastSyncAt(DateTime.now().millisecondsSinceEpoch);
      }
      return result;
    } catch (e) {
      final result = SyncResult(error: '$e');
      lastResult = result;
      return result;
    } finally {
      _syncing = false;
    }
  }

  Future<SyncResult> _doSync(WebDavClient c) async {
    // 下载远端与构建本地快照互不依赖，并行执行
    final remoteBytesF = c.getFile(kBackupPath);
    final localF = buildSnapshot(_appDb, _taskRepository.lastMutationAt);
    final remoteBytes = await remoteBytesF;
    final local = await localF;

    if (remoteBytes == null) {
      await _upload(c, local);
      return const SyncResult(didUpload: true);
    }

    // gzip 解压 + JSON 解析在大快照下是重 CPU 操作，移出主 isolate 避免卡 UI
    final remote = await Isolate.run(() => SyncSnapshot.fromJson(
        jsonDecode(gzipDecode(remoteBytes)) as Map<String, dynamic>));

    // 永远逐条合并，不做"超窗整库覆盖"：本地 revision 依赖内存中的
    // _lastMutationAt，重启即归零，按它判定新旧会静默覆盖掉另一端数据。
    // merged 是 local∪remote 超集，applySnapshot 的整表替换因此是无损的。
    final merged = mergeSnapshots(local, remote);
    await applySnapshot(_appDb, merged);
    onSnapshotApplied?.call();
    await _upload(c, merged);
    return const SyncResult(didUpload: true, didDownload: true, merged: true);
  }

  Future<void> _upload(WebDavClient c, SyncSnapshot snapshot) async {
    // jsonEncode + gzip 在大快照下可达几十 MB 字符串处理，移出主 isolate
    final bytes = await Isolate.run(() => gzipEncode(snapshot.encode()));
    await c.putFile(kBackupPath, bytes);
  }

  /// 数据变更后调用：防抖 30s 后自动上传（无凭据则忽略）。
  void scheduleAutoUpload() {
    if (!_settings.hasCredentials) return;
    _debounce?.cancel();
    _debounce = Timer(kAutoUploadDebounce, () async {
      try {
        await syncNow();
      } catch (e) {
        // 静默失败，下次变更/打开时重试
        AppLogger.error('SyncManager.autoUpload', e);
      }
    });
  }

  /// 退出/测试时清理。
  void dispose() {
    _debounce?.cancel();
  }
}
