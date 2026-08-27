import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/backup/local_backup.dart';
import 'package:ticktodo/core/constants.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/l10n/app_localizations.dart';
import 'package:ticktodo/sync/webdav_client.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;
  bool _saving = false;
  String _syncStatus = '';

  @override
  void initState() {
    super.initState();
    final s = ref.read(syncSettingsProvider);
    _urlCtrl = TextEditingController(text: s.webdavUrl ?? 'https://dav.jianguoyun.com/dav/');
    _userCtrl = TextEditingController(text: s.username ?? '');
    _passCtrl = TextEditingController(text: s.password ?? '');
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveCredentials() async {
    final l10n = AppLocalizations.of(context);
    final settings = ref.read(syncSettingsProvider);
    final url = _urlCtrl.text.trim();
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;
    if (url.isEmpty || user.isEmpty || pass.isEmpty) {
      setState(() => _syncStatus = l10n.settingsIncomplete);
      return;
    }
    setState(() => _saving = true);
    await settings.setCredentials(url, user, pass);
    ref.read(syncManagerProvider).refreshClient();
    // 凭据换绑后立即尝试一次同步（fire-and-forget，失败在状态栏展示）
    unawaited(_syncNow());
    setState(() => _saving = false);
  }

  Future<void> _testConnection() async {
    final l10n = AppLocalizations.of(context);
    final settings = ref.read(syncSettingsProvider);
    if (!settings.hasCredentials) {
      await _saveCredentials();
    }
    setState(() => _syncStatus = l10n.settingsTesting);
    try {
      final client = ref.read(syncManagerProvider).client ??
          WebDavClient(
            settings.webdavUrl!,
            settings.username!,
            settings.password!,
          );
      await client.getFile('TickTodo/');
      setState(() => _syncStatus = l10n.settingsConnected);
    } catch (e) {
      setState(() => _syncStatus = l10n.settingsConnectFailed('$e'));
    }
  }

  Future<void> _syncNow() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _syncStatus = l10n.settingsSyncing);
    final result = await ref.read(syncManagerProvider).syncNow();
    setState(() {
      if (result.success) {
        final parts = <String>[];
        if (result.didUpload) parts.add(l10n.settingsUploaded);
        if (result.didDownload) parts.add(l10n.settingsDownloaded);
        if (result.merged) parts.add(l10n.settingsMerged);
        _syncStatus =
            parts.isEmpty ? l10n.settingsNothingToSync : parts.join(' · ');
      } else {
        _syncStatus = l10n.settingsSyncFailed('${result.error}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(syncSettingsProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final lastSync = settings.lastSyncAt;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          _SectionHeader(l10n.settingsSyncSection),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                TextField(
                  controller: _urlCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.settingsWebdavUrl,
                    hintText: l10n.settingsWebdavHint,
                    prefixIcon: const Icon(Icons.cloud_outlined, size: 20),
                  ),
                ),
                TextField(
                  controller: _userCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.settingsAccount,
                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                  ),
                ),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.settingsAppPassword,
                    prefixIcon: const Icon(Icons.key_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _saving ? null : _saveCredentials,
                      child: Text(l10n.commonSave),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _testConnection,
                      child: Text(l10n.settingsTestConnection),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _syncNow,
                      child: Text(l10n.settingsSyncNow),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _syncStatus.isNotEmpty
                        ? _syncStatus
                        : (lastSync == null
                            ? l10n.settingsNeverSynced
                            : l10n.settingsLastSync(DateTime
                                .fromMillisecondsSinceEpoch(lastSync)
                                .toString()
                                .substring(0, 16)
                                .replaceFirst('T', ' '))),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.settingsPasswordTip,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outlineVariant),
                  ),
                ),
              ],
            ),
          ),
          _SectionHeader(l10n.settingsBackupSection),
          const _LocalBackupSection(),
          _SectionHeader(l10n.settingsAppearance),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(l10n.settingsTheme),
            trailing: DropdownButton<ThemeMode>(
              value: ref.watch(themeModeProvider),
              items: [
                DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text(l10n.settingsThemeSystem)),
                DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text(l10n.settingsThemeLight)),
                DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text(l10n.settingsThemeDark)),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref.read(themeModeProvider.notifier).state = v;
                }
              },
            ),
          ),
          _SectionHeader(l10n.settingsAbout),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.appTitle),
            subtitle: Text(l10n.settingsAboutSubtitle(kAppVersion)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

/// 本地备份区块：上次备份时间 + 立即备份 + 最近备份列表。
class _LocalBackupSection extends ConsumerStatefulWidget {
  const _LocalBackupSection();

  @override
  ConsumerState<_LocalBackupSection> createState() => _LocalBackupSectionState();
}

class _LocalBackupSectionState extends ConsumerState<_LocalBackupSection> {
  List<BackupEntry> _backups = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final backups = await ref.read(localBackupProvider)?.listBackups();
    if (!mounted) return;
    setState(() => _backups = backups ?? const []);
  }

  Future<void> _backupNow() async {
    final l10n = AppLocalizations.of(context);
    final mgr = ref.read(localBackupProvider);
    if (mgr == null) return;
    setState(() => _busy = true);
    try {
      final path = await mgr.backupNow();
      if (!mounted) return;
      setState(() {
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(path == null ? l10n.settingsBackupFailed : l10n.settingsBackupSuccess),
      ));
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmtTime(int? ms, AppLocalizations l10n) {
    if (ms == null) return l10n.settingsBackupNever;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final s = dt.toString().substring(0, 16);
    return s.replaceFirst('T', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final mgr = ref.watch(localBackupProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsBackupLast(_fmtTime(mgr?.lastBackupAt, l10n)),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: (_busy || mgr == null) ? null : _backupNow,
            icon: const Icon(Icons.save_alt, size: 18),
            label: Text(_busy ? l10n.settingsBackupBusy : l10n.settingsBackupNow),
          ),
          const SizedBox(height: 8),
          if (_backups.isNotEmpty)
            ..._backups.take(3).map((b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${b.name} · ${b.sizeLabel}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outlineVariant),
                  ),
                )),
        ],
      ),
    );
  }
}
