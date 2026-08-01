import 'package:shared_preferences/shared_preferences.dart';

class SyncSettings {
  static const _kUrl = 'webdav_url';
  static const _kUser = 'webdav_user';
  static const _kPass = 'webdav_pass';
  static const _kLastSync = 'webdav_last_sync';

  final SharedPreferences _prefs;

  SyncSettings(this._prefs);

  String? get webdavUrl => _prefs.getString(_kUrl);
  String? get username => _prefs.getString(_kUser);
  String? get password => _prefs.getString(_kPass);
  int? get lastSyncAt => _prefs.getInt(_kLastSync);

  bool get hasCredentials =>
      (webdavUrl?.isNotEmpty ?? false) &&
      (username?.isNotEmpty ?? false) &&
      (password?.isNotEmpty ?? false);

  Future<void> setCredentials(String url, String user, String pass) async {
    await _prefs.setString(_kUrl, url);
    await _prefs.setString(_kUser, user);
    await _prefs.setString(_kPass, pass);
  }

  Future<void> setLastSyncAt(int epochMs) async {
    await _prefs.setInt(_kLastSync, epochMs);
  }
}
