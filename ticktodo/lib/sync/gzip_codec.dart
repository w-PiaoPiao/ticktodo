import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

Uint8List gzipEncode(String jsonStr) {
  final bytes = utf8.encode(jsonStr);
  return Uint8List.fromList(GZipEncoder().encode(bytes)!);
}

String gzipDecode(Uint8List compressed) {
  final bytes = GZipDecoder().decodeBytes(compressed);
  return utf8.decode(bytes);
}
