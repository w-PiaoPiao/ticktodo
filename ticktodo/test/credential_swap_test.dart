import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ticktodo/core/providers.dart';
import 'package:ticktodo/features/settings/settings_screen.dart';
import 'package:ticktodo/sync/sync_manager.dart';
import 'package:ticktodo/sync/sync_settings.dart';

import 'support/in_memory_credential_store.dart';
import 'support/test_app.dart';

class _MockSyncManager extends Mock implements SyncManager {}

void main() {
  late SyncSettings settings;
  late _MockSyncManager syncManager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    settings = SyncSettings(prefs, InMemoryCredentialStore());
    await settings.load();
    syncManager = _MockSyncManager();
  });

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        syncSettingsProvider.overrideWithValue(settings),
        syncManagerProvider.overrideWithValue(syncManager),
      ],
      child: testApp(const SettingsScreen()),
    );
  }

  Future<void> fillAndSave(WidgetTester tester) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'https://dav.jianguoyun.com/dav/');
    await tester.enterText(fields.at(1), 'u@example.com');
    await tester.enterText(fields.at(2), 'apppass');
    await tester.tap(find.widgetWithText(OutlinedButton, '保存'));
    await tester.pump();
  }

  testWidgets('保存凭据：refreshClient + syncNow 均被触发，凭据落盘', (tester) async {
    when(() => syncManager.refreshClient()).thenReturn(null);
    when(() => syncManager.syncNow())
        .thenAnswer((_) async => const SyncResult(didUpload: true));

    await tester.pumpWidget(buildApp());
    await fillAndSave(tester);

    verify(() => syncManager.refreshClient()).called(1);
    verify(() => syncManager.syncNow()).called(1);
    expect(settings.webdavUrl, 'https://dav.jianguoyun.com/dav/');
    expect(settings.hasCredentials, isTrue);
    // 同步结果状态展示
    await tester.pump();
    expect(find.textContaining('已上传'), findsOneWidget);
  });

  testWidgets('同步失败时状态栏显示错误', (tester) async {
    when(() => syncManager.refreshClient()).thenReturn(null);
    when(() => syncManager.syncNow())
        .thenAnswer((_) async => const SyncResult(error: '网络错误'));

    await tester.pumpWidget(buildApp());
    await fillAndSave(tester);
    await tester.pump();

    expect(find.textContaining('同步失败'), findsOneWidget);
    verify(() => syncManager.syncNow()).called(1);
  });

  testWidgets('凭据不完整时不触发同步', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.enterText(find.byType(TextField).at(0), 'https://x/');
    await tester.tap(find.widgetWithText(OutlinedButton, '保存'));
    await tester.pump();

    verifyNever(() => syncManager.refreshClient());
    verifyNever(() => syncManager.syncNow());
    expect(find.text('请填写完整的账号信息'), findsOneWidget);
    expect(settings.hasCredentials, isFalse);
  });
}