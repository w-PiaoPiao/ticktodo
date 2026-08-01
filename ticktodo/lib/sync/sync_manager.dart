import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/data/repositories/task_repository.dart';
import 'package:ticktodo/sync/gzip_codec.dart';
import 'package:ticktodo/sync/snapshot.dart';
import 'package:ticktodo/sync/snapshot_merge.dart';
import 'package:ticktodo/sync/sync_settings.dart';
import 'package:ticktodo/sync/webdav_client.dart';

const String kBackupPath = 'TickTodo/todo_backup.json.gz';
const Duration kAutoUploadDebounce = Duration(seconds: 30);
const Duration kConflictWindow = Duration(minutes: 5);

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
    final remoteBytes = await c.getFile(kBackupPath);
    final local = await buildSnapshot(_appDb, _taskRepository.lastMutationAt);

    if (remoteBytes == null) {
      await _upload(c, local);
      return const SyncResult(didUpload: true);
    }

    final remote = SyncSnapshot.fromJson(
      jsonDecode(gzipDecode(remoteBytes)) as Map<String, dynamic>,
    );

    final diff = (local.revision - remote.revision).abs();
    if (diff > kConflictWindow.inMilliseconds) {
      if (local.revision > remote.revision) {
        await _upload(c, local);
        return const SyncResult(didUpload: true);
      } else {
        await applySnapshot(_appDb, remote);
        return const SyncResult(didDownload: true);
      }
    }

    final merged = mergeSnapshots(local, remote);
    await applySnapshot(_appDb, merged);
    await _upload(c, merged);
    return const SyncResult(didUpload: true, didDownload: true, merged: true);
  }

  Future<void> _upload(WebDavClient c, SyncSnapshot snapshot) async {
    final bytes = gzipEncode(snapshot.encode());
    await c.putFile(kBackupPath, Uint8List.fromList(bytes));
  }

  /// 数据变更后调用：防抖 30s 后自动上传（无凭据则忽略）。
  void scheduleAutoUpload() {
    if (!_settings.hasCredentials) return;
    _debounce?.cancel();
    _debounce = Timer(kAutoUploadDebounce, () async {
      try {
        await syncNow();
      } catch (_) {
        // 静默失败，下次变更/打开时重试
      }
    });
  }

  /// 退出/测试时清理。
  void dispose() {
    _debounce?.cancel();
  }
}
