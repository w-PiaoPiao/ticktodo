import 'package:ticktodo/sync/credential_store.dart';

/// 测试用内存实现：行为同 SecureCredentialStore，但不需要平台通道。
class InMemoryCredentialStore implements CredentialStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}