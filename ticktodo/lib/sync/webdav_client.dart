import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class WebDavException implements Exception {
  WebDavException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 极简 WebDAV 客户端：只支持 GET/PUT（坚果云备份场景足够）。
class WebDavClient {
  WebDavClient(
    this.baseUrl,
    this.username,
    this.password, {
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  })  : _client = client ?? http.Client(),
        _base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';

  final String baseUrl;
  final String username;
  final String password;
  final Duration timeout;
  final http.Client _client;
  final String _base;

  Map<String, String> get _headers => {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$username:$password'))}',
      };

  Future<void> putFile(String path, List<int> bytes) async {
    final uri = Uri.parse('$_base$path');
    final res = await _client
        .put(uri, headers: _headers, body: bytes)
        .timeout(timeout);
    if (res.statusCode >= 400) {
      throw WebDavException('上传失败 (HTTP ${res.statusCode})');
    }
  }

  /// 下载文件；404 返回 null，其余错误抛异常。
  Future<Uint8List?> getFile(String path) async {
    final uri = Uri.parse('$_base$path');
    final res = await _client.get(uri, headers: _headers).timeout(timeout);
    if (res.statusCode == 404) return null;
    if (res.statusCode >= 400) {
      throw WebDavException('下载失败 (HTTP ${res.statusCode})');
    }
    return res.bodyBytes;
  }
}
