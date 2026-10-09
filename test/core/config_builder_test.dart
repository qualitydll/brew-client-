import 'package:brew/core/config_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android external TUN keeps Mihomo TUN disabled and enables DNS', () {
    final config = applyCoreOptions(
      const <String, dynamic>{},
      const CoreOptions(
        mixedPort: 7890,
        apiPort: 9097,
        secret: 'test-secret',
        mode: 'rule',
        tun: false,
        allowLan: false,
        externalTun: true,
      ),
    );

    expect(config['tun'], {'enable': false});
    expect(config['dns'], isA<Map<String, dynamic>>());
    expect((config['dns'] as Map<String, dynamic>)['enable'], isTrue);
  });
}
