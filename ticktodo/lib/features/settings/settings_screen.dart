import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/sync/sync_settings.dart';
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
    final settings = ref.read(syncSettingsProvider);
    final url = _urlCtrl.text.trim();
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;
    if (url.isEmpty || user.isEmpty || pass.isEmpty) {
      setState(() => _syncStatus = '请填写完整的账号信息');
      return;
    }
    setState(() => _saving = true);
    await settings.setCredentials(url, user, pass);
    ref.read(syncManagerProvider).refreshClient();
    setState(() {
      _saving = false;
      _syncStatus = '已保存';
    });
  }

  Future<void> _testConnection() async {
    final settings = ref.read(syncSettingsProvider);
    if (!settings.hasCredentials) {
      await _saveCredentials();
    }
    setState(() => _syncStatus = '测试中…');
    try {
      final client = ref.read(syncManagerProvider).client ??
          WebDavClient(
            settings.webdavUrl!,
            settings.username!,
            settings.password!,
          );
      await client.getFile('TickTodo/');
      setState(() => _syncStatus = '连接成功');
    } catch (e) {
      setState(() => _syncStatus = '连接失败：$e');
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncStatus = '同步中…');
    final result = await ref.read(syncManagerProvider).syncNow();
    setState(() {
      if (result.success) {
        final parts = <String>[];
        if (result.didUpload) parts.add('已上传');
        if (result.didDownload) parts.add('已下载');
        if (result.merged) parts.add('已合并');
        _syncStatus = parts.isEmpty ? '无需同步' : parts.join(' · ');
      } else {
        _syncStatus = '同步失败：${result.error}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(syncSettingsProvider);
    final theme = Theme.of(context);
    final lastSync = settings.lastSyncAt;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const _SectionHeader('坚果云同步'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                TextField(
                  controller: _urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'WebDAV 地址',
                    hintText: 'https://dav.jianguoyun.com/dav/',
                    prefixIcon: Icon(Icons.cloud_outlined, size: 20),
                  ),
                ),
                TextField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(
                    labelText: '账号（坚果云邮箱）',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                ),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '应用密码',
                    prefixIcon: Icon(Icons.key_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _saving ? null : _saveCredentials,
                      child: const Text('保存'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _testConnection,
                      child: const Text('测试连接'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _syncNow,
                      child: const Text('立即同步'),
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
                            ? '尚未同步'
                            : '上次同步：${DateTime.fromMillisecondsSinceEpoch(lastSync).toString().substring(0, 16)}'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '提示：坚果云「应用密码」在坚果云网页版 → 账户信息 → 安全选项 中生成，'
                    '不要直接使用登录密码。',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outlineVariant),
                  ),
                ),
              ],
            ),
          ),
          const _SectionHeader('外观'),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('主题'),
            trailing: DropdownButton<ThemeMode>(
              value: ref.watch(themeModeProvider),
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('跟随系统')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('浅色')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('深色')),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref.read(themeModeProvider.notifier).state = v;
                }
              },
            ),
          ),
          const _SectionHeader('关于'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('滴答清单Pro'),
            subtitle: Text('版本 1.0.0 · 本地优先 · 坚果云备份同步'),
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
