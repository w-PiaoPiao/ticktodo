import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ticktodo/sync/webdav_client.dart';

void main() {
  late List<http.Request> requests;

  MockClient mock(int Function(http.Request) responder) {
    return MockClient((request) async {
      requests.add(request);
      final code = responder(request);
      return http.Response(code >= 400 ? 'err' : 'ok', code);
    });
  }

  setUp(() {
    requests = [];
  });

  test('PUT 带 Basic Auth 与 body', () async {
    final client = WebDavClient(
      'https://dav.jianguoyun.com/dav/',
      'user@example.com',
      'apppass',
      client: mock((r) => 201),
    );
    await client.putFile('TickTodo/todo_backup.json.gz', [1, 2, 3]);
    final req = requests.single;
    expect(req.method, 'PUT');
    expect(req.url.toString(), 'https://dav.jianguoyun.com/dav/TickTodo/todo_backup.json.gz');
    expect(req.headers['Authorization'],
        'Basic ${base64Encode(utf8.encode('user@example.com:apppass'))}');
    expect(req.bodyBytes, [1, 2, 3]);
  });

  test('baseUrl 自动补斜杠', () async {
    final client = WebDavClient(
      'https://dav.jianguoyun.com/dav',
      'u',
      'p',
      client: mock((r) => 200),
    );
    await client.putFile('a/b.json', [1]);
    expect(requests.single.url.toString(),
        'https://dav.jianguoyun.com/dav/a/b.json');
  });

  test('GET 返回内容', () async {
    final client = WebDavClient(
      'https://dav.jianguoyun.com/dav/',
      'u',
      'p',
      client: MockClient((request) async {
        return http.Response.bytes(Uint8List.fromList([9, 8, 7]), 200);
      }),
    );
    final data = await client.getFile('f.json');
    expect(data, [9, 8, 7]);
  });

  test('GET 404 返回 null', () async {
    final client = WebDavClient(
      'https://dav.jianguoyun.com/dav/',
      'u',
      'p',
      client: mock((r) => 404),
    );
    expect(await client.getFile('f.json'), isNull);
  });

  test('PUT 400 抛异常', () async {
    final client = WebDavClient(
      'https://dav.jianguoyun.com/dav/',
      'u',
      'p',
      client: mock((r) => 401),
    );
    expect(() => client.putFile('f.json', [1]), throwsA(isA<WebDavException>()));
  });
}
