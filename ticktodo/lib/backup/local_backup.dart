import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ticktodo/core/logger.dart';
import 'package:ticktodo/data/db/app_database.dart';
import 'package:ticktodo/sync/gzip_codec.dart';
import 'package:ticktodo/sync/snapshot.dart';

/// 本地快照备份：与应用文档目录 backups/ 下的 gzip 快照文件交互。
///
/// - 自动备份节流：距上次备份 > [kAutoBackupInterval] 才执行
/// - 保留上限 [kMaxBackups] 份，启动时清理更旧的
class LocalBackupManager {
  // 参数名公开、字段私有（与 SyncManager 同因），关闭该 lint。
  // ignore_for_file: prefer_initializing_formals
  LocalBackupManager({
    required AppDatabase appDb,
    required SharedPreferences prefs,
    Directory? overrideDir,
  })  : _appDb = appDb,
        _prefs = prefs,
        _overrideDir = overrideDir;

  static const int kMaxBackups = 7;
  static const Duration kAutoBackupInterval = Duration(hours: 24);
  static const String kLastBackupKey = 'local_backup_last_at';
  static const String _prefix = 'todo_backup_';
  static const String _suffix = '.json.gz';

  final AppDatabase _appDb;
  final SharedPreferences _prefs;

  /// 测试注入用：替换真实文档目录。
  final Directory? _overrideDir;

  Future<Directory> _backupDir() async {
    final root = _overrideDir ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'backups'));
    await dir.create(recursive: true);
    return dir;
  }

  /// 上次备份时间（epoch ms），从未备份则 null。
  int? get lastBackupAt => _prefs.getInt(kLastBackupKey);

  /// 检查是否超过自动备份间隔（未备份或超 24h）。
  bool get shouldAutoBackup {
    final last = lastBackupAt;
    if (last == null) return true;
    return DateTime.now().millisecondsSinceEpoch - last >=
        kAutoBackupInterval.inMilliseconds;
  }

  /// 生成一份备份，返回备份文件路径；失败返回 null 并记录日志。
  Future<String?> backupNow() async {
    try {
      final dir = await _backupDir();
      final stamp = DateTime.now();
      final name = '$_prefix${stamp.year}'
          '${stamp.month.toString().padLeft(2, '0')}'
          '${stamp.day.toString().padLeft(2, '0')}'
          '_${stamp.hour.toString().padLeft(2, '0')}'
          '${stamp.minute.toString().padLeft(2, '0')}'
          '${stamp.second.toString().padLeft(2, '0')}$_suffix';
      final file = File(p.join(dir.path, name));
      final snapshot = await buildSnapshot(_appDb, _nowMs());
      await file.writeAsBytes(
          gzipEncode(snapshot.encode()), flush: true);
      await _prefs.setInt(kLastBackupKey, _nowMs());
      await prune();
      AppLogger.info('LocalBackup.backupNow', '已写入 ${file.path}');
      return file.path;
    } catch (e) {
      AppLogger.error('LocalBackup.backupNow', e);
      return null;
    }
  }

  /// 自动备份入口（main 启动时调用）：超间隔才执行。
  Future<bool> autoBackupIfDue() async {
    if (!shouldAutoBackup) return false;
    final path = await backupNow();
    return path != null;
  }

  /// 数据变更后调用：30s 防抖后若超间隔则备份（无备份需求则跳过）。
  Timer? _backupDebounce;

  void scheduleAutoBackup() {
    _backupDebounce?.cancel();
    _backupDebounce = Timer(const Duration(seconds: 30), () async {
      try {
        await autoBackupIfDue();
      } catch (e) {
        AppLogger.warn('LocalBackup.scheduleAutoBackup', '$e');
      }
    });
  }

  void dispose() {
    _backupDebounce?.cancel();
  }

  /// 保留最近 [kMaxBackups] 份，删除更旧的。
  Future<void> prune() async {
    try {
      final dir = await _backupDir();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) =>
              p.basename(f.path).startsWith(_prefix) &&
              p.basename(f.path).endsWith(_suffix))
          .toList()
        ..sort((a, b) =>
            b.statSync().modified.compareTo(a.statSync().modified));
      for (final f in files.skip(kMaxBackups)) {
        try {
          await f.delete();
          AppLogger.info('LocalBackup.prune', '清理旧备份 ${f.path}');
        } catch (e) {
          AppLogger.warn('LocalBackup.prune', '删除失败 ${f.path}: $e');
        }
      }
    } catch (e) {
      AppLogger.warn('LocalBackup.prune', '$e');
    }
  }

  /// 现有备份列表（按时间倒序）：文件名 + 修改时间 + 大小。
  Future<List<BackupEntry>> listBackups() async {
    try {
      final dir = await _backupDir();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) =>
              p.basename(f.path).startsWith(_prefix) &&
              p.basename(f.path).endsWith(_suffix))
          .toList()
        ..sort((a, b) =>
            b.statSync().modified.compareTo(a.statSync().modified));
      return files
          .map((f) => BackupEntry(
                name: p.basename(f.path),
                modifiedAt: f.statSync().modified,
                sizeBytes: f.statSync().size,
              ))
          .toList();
    } catch (e) {
      AppLogger.warn('LocalBackup.listBackups', '$e');
      return const [];
    }
  }

  int _nowMs() => DateTime.now().millisecondsSinceEpoch;
}

/// 备份文件信息（设置页展示）。
class BackupEntry {
  const BackupEntry({
    required this.name,
    required this.modifiedAt,
    required this.sizeBytes,
  });

  final String name;
  final DateTime modifiedAt;
  final int sizeBytes;

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}