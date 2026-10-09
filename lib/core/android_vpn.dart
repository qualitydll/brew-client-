import 'package:flutter/services.dart';

class AndroidVpn {
  static const _channel = MethodChannel('dev.brew.brew/vpn');

  static Future<void> prepare() async {
    await _channel.invokeMethod<bool>('prepareVpn');
  }

  static Future<String?> validateConfig(String path) =>
      _channel.invokeMethod<String>('validateConfig', {'path': path});

  static Future<void> start(String configPath) =>
      _channel.invokeMethod<void>('startVpn', {'configPath': configPath});

  static Future<void> stop() => _channel.invokeMethod<void>('stopVpn');
}
