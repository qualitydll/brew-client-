import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'config_builder.dart';

class MihomoApi {
  MihomoApi({required this.port, required this.secret});

  final int port;
  final String secret;
  final http.Client _client = http.Client();

  Uri _uri(String path, [Map<String, String>? query]) => Uri(
    scheme: 'http',
    host: '127.0.0.1',
    port: port,
    path: path,
    queryParameters: query,
  );

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $secret',
    'Content-Type': 'application/json',
  };

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final res = await _client
        .get(_uri(path, query), headers: _headers)
        .timeout(timeout);
    if (res.statusCode >= 400) {
      throw MihomoApiException(res.statusCode, utf8.decode(res.bodyBytes));
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<String> version() async {
    final j = await _getJson('/version', timeout: const Duration(seconds: 1));
    return j['version']?.toString() ?? '';
  }

  Future<Map<String, dynamic>> proxies() async {
    final j = await _getJson('/proxies');
    return (j['proxies'] as Map).cast<String, dynamic>();
  }

  Future<void> select(String group, String name) async {
    final res = await _client.put(
      _uri('/proxies/${Uri.encodeComponent(group)}'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    if (res.statusCode >= 400) {
      throw MihomoApiException(res.statusCode, res.body);
    }
  }

  /// Returns delay in ms, or -1 on timeout/failure.
  Future<int> delay(String name, {int timeoutMs = 5000}) async {
    try {
      final j = await _getJson(
        '/proxies/${Uri.encodeComponent(name)}/delay',
        query: {'url': kTestUrl, 'timeout': '$timeoutMs'},
        timeout: Duration(milliseconds: timeoutMs + 2000),
      );
      return (j['delay'] as num?)?.toInt() ?? -1;
    } catch (_) {
      return -1;
    }
  }

  Future<Map<String, int>> groupDelay(
    String group, {
    int timeoutMs = 5000,
  }) async {
    try {
      final j = await _getJson(
        '/group/${Uri.encodeComponent(group)}/delay',
        query: {'url': kTestUrl, 'timeout': '$timeoutMs'},
        timeout: Duration(milliseconds: timeoutMs + 5000),
      );
      return j.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  Future<void> patchConfig(Map<String, dynamic> patch) async {
    final res = await _client.patch(
      _uri('/configs'),
      headers: _headers,
      body: jsonEncode(patch),
    );
    if (res.statusCode >= 400) {
      throw MihomoApiException(res.statusCode, res.body);
    }
  }

  Future<void> closeConnections() async {
    await _client.delete(_uri('/connections'), headers: _headers);
  }

  /// Streams newline-delimited JSON objects from long-lived endpoints
  /// such as `/traffic` and `/logs`.
  Stream<Map<String, dynamic>> stream(
    String path, [
    Map<String, String>? query,
  ]) async* {
    final client = http.Client();
    try {
      final req = http.Request('GET', _uri(path, query))
        ..headers.addAll(_headers);
      final res = await client.send(req);
      yield* res.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .where((l) => l.trim().isNotEmpty)
          .map((l) => jsonDecode(l) as Map<String, dynamic>);
    } finally {
      client.close();
    }
  }

  void close() => _client.close();
}

class MihomoApiException implements Exception {
  MihomoApiException(this.status, this.body);
  final int status;
  final String body;
  @override
  String toString() => 'mihomo API $status: $body';
}
