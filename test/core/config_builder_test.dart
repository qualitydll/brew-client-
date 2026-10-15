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

  test('VLESS URI preserves PQ encryption, packet encoding, Reality and Vision', () {
    const link = 'vless://00000000-0000-4000-8000-000000000001@node.example:443'
        '?encryption=mlkem768x25519plus.native%2Fxorpub%2Frandom.1rtt'
        '&security=reality&pbk=public-key-placeholder&sid=abcd1234'
        '&sni=example.org&fp=chrome&flow=xtls-rprx-vision'
        '&packet-encoding=xudp&type=tcp#pq-test';

    final parsed = parseSubscription(link);
    expect(parsed.proxyCount, 1);
    final proxy = parsed.proxies.single;
    expect(proxy['type'], 'vless');
    expect(proxy['flow'], 'xtls-rprx-vision');
    expect(proxy['encryption'], 'mlkem768x25519plus.native/xorpub/random.1rtt');
    expect(proxy['packet-encoding'], 'xudp');
    expect(proxy['client-fingerprint'], 'chrome');
    expect(proxy['servername'], 'example.org');
    expect(proxy['reality-opts'], {
      'public-key': 'public-key-placeholder',
      'short-id': 'abcd1234',
    });
  });

  test('AnyTLS URI preserves SNI, ALPN, fingerprint and verification setting', () {
    const link = 'anytls://test-password@node.example:443'
        '?sni=example.org&alpn=h2%2Chttp%2F1.1&fp=chrome&insecure=0#anytls-test';

    final parsed = parseSubscription(link);
    expect(parsed.proxyCount, 1);
    final proxy = parsed.proxies.single;
    expect(proxy['type'], 'anytls');
    expect(proxy['password'], 'test-password');
    expect(proxy['sni'], 'example.org');
    expect(proxy['alpn'], ['h2', 'http/1.1']);
    expect(proxy['client-fingerprint'], 'chrome');
    expect(proxy.containsKey('skip-cert-verify'), isFalse);
  });

  test('VLESS XHTTP preserves the transport mode', () {
    const link = 'vless://00000000-0000-4000-8000-000000000001@node.example:443'
        '?security=tls&sni=example.org&type=xhttp&path=%2Fedge&mode=auto#xhttp-test';

    final proxy = parseSubscription(link).proxies.single;
    expect(proxy['network'], 'xhttp');
    expect(proxy['xhttp-opts'], {'path': '/edge', 'mode': 'auto'});
  });

  test('Android TUN enables DNS while preserving provider DNS options', () {
    final config = applyCoreOptions(
      const {
        'dns': {
          'enable': false,
          'nameserver': ['https://dns.example/dns-query'],
          'fallback': ['1.1.1.1'],
          'respect-rules': true,
        },
      },
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

    expect(config['dns'], {
      'enable': true,
      'ipv6': true,
      'enhanced-mode': 'fake-ip',
      'fake-ip-range': '198.18.0.1/16',
      'fake-ip-filter': [
        '*.lan',
        '*.local',
        'localhost.ptlogin2.qq.com',
        '+.msftconnecttest.com',
        '+.msftncsi.com',
      ],
      'default-nameserver': ['1.1.1.1', '8.8.8.8'],
      'nameserver': ['https://dns.example/dns-query'],
      'fallback': ['1.1.1.1'],
      'respect-rules': true,
    });
  });

}
