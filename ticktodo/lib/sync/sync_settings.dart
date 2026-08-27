import 'package:shared_preferences/shared_preferences.dart';
import 'package:ticktodo/sync/credential_store.dart';

/// WebDAV 同步设置：
/// - 敏感凭据（url/账号/密码）存系统安全存储（Keychain/Keystore），
///   启动时通过 [load] 载入内存缓存；
/// - 非敏感项（上次同步时间）保留 SharedPreferences。
class SyncSettings {
  static const _kUrl = 'webdav_url';
  static const _kUser = 'webdav_user';
  static const _kPass = 'webdav_pass';
  static const _kLastSync = 'webdav_last_sync';

  /// 旧版明文存储键（用于一次性迁移）。
  static const legacyPrefsKeys = [_kUrl, _kUser, _kPass];

  final SharedPreferences _prefs;
  final CredentialStore _store;

  SyncSettings(this._prefs, this._store);

  String? _url;
  String? _user;
  String? _pass;

  String? get webdavUrl => _url;
  String? get username => _user;
  String? get password => _pass;
  int? get lastSyncAt => _prefs.getInt(_kLastSync);

  /// 从安全存储加载凭据到内存（main 启动时调用）。
  Future<void> load() async {
    _url = await _store.read(_kUrl);
    _user = await _store.read(_kUser);
    _pass = await _store.read(_kPass);
  }

  bool get hasCredentials =>
      (_url?.isNotEmpty ?? false) &&
      (_user?.isNotEmpty ?? false) &&
      (_pass?.isNotEmpty ?? false);

  Future<void> setCredentials(String url, String user, String pass) async {
    await _store.write(_kUrl, url);
    await _store.write(_kUser, user);
    await _store.write(_kPass, pass);
    _url = url;
    _user = user;
    _pass = pass;
  }

  Future<void> setLastSyncAt(int epochMs) async {
    await _prefs.setInt(_kLastSync, epochMs);
  }

  /// 一次性迁移：把旧版 SharedPreferences 明文凭据搬入安全存储并清除旧键。
  /// 若安全存储已有凭据则以安全存储为准（删除旧明文）。
  Future<void> migrateLegacyPrefs() async {
    final url = _prefs.getString(_kUrl);
    final user = _prefs.getString(_kUser);
    final pass = _prefs.getString(_kPass);
    final hasLegacy = url != null || user != null || pass != null;
    if (!hasLegacy) return;

    if (_url == null && url != null) {
      await _store.write(_kUrl, url);
      _url = url;
    }
    if (_user == null && user != null) {
      await _store.write(_kUser, user);
      _user = user;
    }
    if (_pass == null && pass != null) {
      await _store.write(_kPass, pass);
      _pass = pass;
    }
    await _prefs.remove(_kUrl);
    await _prefs.remove(_kUser);
    await _prefs.remove(_kPass);
  }
}