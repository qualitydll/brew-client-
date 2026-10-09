import 'dart:io';

import 'package:brew/core/mihomo_config_path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('prepares config.yaml in the service home directory', () async {
    final dataDirectory = await Directory.systemTemp.createTemp('brew-mihomo-');
    addTearDown(() => dataDirectory.delete(recursive: true));

    final home = mihomoHomeDirectory(dataDirectory.path);
    final file = await prepareMihomoConfigFile(dataDirectory.path);
    await file.writeAsString('mixed-port: 7890\n');

    expect(p.dirname(file.path), home);
    expect(p.basename(file.path), mihomoConfigFileName);
    expect(
      await File(p.join(home, mihomoConfigFileName)).readAsString(),
      'mixed-port: 7890\n',
    );
  });
}
