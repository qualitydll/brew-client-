import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Downloads and installs the official Mihomo binary for this Android ABI.
/// The binary is kept in app-private storage, not beside the APK.
class AndroidCoreInstaller {
  static const _releaseApi =
      'https://api.github.com/repos/MetaCubeX/mihomo/releases/latest';

  static String? get _assetPrefix {
    switch (Abi.current()) {
      case Abi.androidArm64:
        return 'mihomo-android-arm64-v8-';
      case Abi.androidArm:
        return 'mihomo-android-armv7-';
      case Abi.androidX64:
        return 'mihomo-android-amd64-';
      case Abi.androidIA32:
        return 'mihomo-android-386-';
      default:
        return null;
    }
  }

  static Future<String> install(String dataDir) async {
    final prefix = _assetPrefix;
    if (prefix == null) {
      throw UnsupportedError('Архитектура Android не поддерживается Mihomo');
    }

    final coreDir = Directory(p.join(dataDir, 'core'));
    await coreDir.create(recursive: true);
    final target = File(p.join(coreDir.path, 'mihomo'));

    // Reuse a previously installed executable if it still starts correctly.
    if (await target.exists()) {
      try {
        final result = await Process.run(target.path, ['-v'])
            .timeout(const Duration(seconds: 5));
        if (result.exitCode == 0) return target.path;
      } catch (_) {}
      try {
        await target.delete();
      } catch (_) {}
    }

    final client = http.Client();
    try {
      final releaseResponse = await client
          .get(
            Uri.parse(_releaseApi),
            headers: {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Brew-VPN-Client',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (releaseResponse.statusCode != 200) {
        throw HttpException(
          'GitHub вернул HTTP ${releaseResponse.statusCode} при поиске Mihomo',
        );
      }

      final release = jsonDecode(releaseResponse.body) as Map<String, dynamic>;
      final assets = release['assets'] as List<dynamic>? ?? const [];
      final asset = assets.cast<Map<String, dynamic>>().where((item) {
        final name = item['name']?.toString() ?? '';
        return name.startsWith(prefix) && name.endsWith('.gz');
      }).firstOrNull;
      final url = asset?['browser_download_url']?.toString();
      if (url == null || url.isEmpty) {
        throw const HttpException(
          'Не найден официальный бинарник Mihomo для архитектуры этого устройства',
        );
      }

      final binaryResponse = await client
          .get(
            Uri.parse(url),
            headers: {'User-Agent': 'Brew-VPN-Client'},
          )
          .timeout(const Duration(seconds: 90));
      if (binaryResponse.statusCode != 200) {
        throw HttpException(
          'Не удалось скачать Mihomo: HTTP ${binaryResponse.statusCode}',
        );
      }

      final bytes = GZipCodec().decode(binaryResponse.bodyBytes);
      final temporary = File('${target.path}.download');
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.setExecutable(true);
      await temporary.rename(target.path);

      final check = await Process.run(target.path, ['-v'])
          .timeout(const Duration(seconds: 10));
      if (check.exitCode != 0) {
        throw const ProcessException(
          'mihomo',
          ['-v'],
          'Скачанное ядро не запустилось',
        );
      }
      return target.path;
    } finally {
      client.close();
    }
  }
}
