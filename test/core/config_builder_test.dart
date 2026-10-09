import 'package:brew/core/config_builder.dart';
import 'package:brew/core/link_parser.dart';
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

  test('Mihomo provider rules survive subscription parsing and config setup', () {
    const subscription = '''
mixed-port: 7890
proxy-providers:
  locations:
    type: http
    url: https://example.org/locations.yaml
    path: ./providers/locations.yaml
    interval: 3600
proxy-groups:
  - name: PROXY
    type: select
    use:
      - locations
rule-providers:
  ads:
    type: http
    behavior: domain
    url: https://example.org/ads.yaml
    path: ./rules/ads.yaml
    interval: 3600
rules:
  - DOMAIN-SUFFIX,example.org,DIRECT
  - RULE-SET,ads,REJECT
  - MATCH,PROXY
''';

    final parsed = parseSubscription(subscription);
    expect(parsed.clashConfig, isNotNull);

    final config = applyCoreOptions(
      baseConfigFor(parsed),
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

    expect(config['rules'], [
      'DOMAIN-SUFFIX,example.org,DIRECT',
      'RULE-SET,ads,REJECT',
      'MATCH,PROXY',
    ]);
    expect(
      ((config['proxy-providers'] as Map)['locations'] as Map)['url'],
      'https://example.org/locations.yaml',
    );
    expect(
      ((config['rule-providers'] as Map)['ads'] as Map)['url'],
      'https://example.org/ads.yaml',
    );
  });

  test('user rules precede subscription rules without replacing them', () {
    final config = applyCoreOptions(
      const {
        'rules': [
          'DOMAIN-SUFFIX,provider.example,DIRECT',
          'MATCH,PROXY',
        ],
      },
      const CoreOptions(
        mixedPort: 7890,
        apiPort: 9097,
        secret: 'test-secret',
        mode: 'rule',
        tun: false,
        allowLan: false,
        userRules: [
          'DOMAIN-SUFFIX,custom.example,PROXY',
          'IP-CIDR,203.0.113.0/24,DIRECT,no-resolve',
        ],
      ),
    );

    expect(config['rules'], [
      'DOMAIN-SUFFIX,custom.example,PROXY',
      'IP-CIDR,203.0.113.0/24,DIRECT,no-resolve',
      'DOMAIN-SUFFIX,provider.example,DIRECT',
      'MATCH,PROXY',
    ]);
  });
}
