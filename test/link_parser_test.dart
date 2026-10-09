import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:brew/core/config_builder.dart';
import 'package:brew/core/link_parser.dart';

const _clashYaml = '''
proxies:
  - name: node-1
    type: socks5
    server: 127.0.0.1
    port: 1080
proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - node-1
      - DIRECT
rules:
  - DOMAIN-SUFFIX,example.com,PROXY
  - MATCH,PROXY
''';

void main() {
  group('provider routing', () {
    test('keeps rules and groups from a raw Clash subscription', () {
      final parsed = parseSubscription(_clashYaml);
      expect(parsed.clashConfig, isNotNull);

      final config = baseConfigFor(parsed);
      expect(config['rules'], contains('DOMAIN-SUFFIX,example.com,PROXY'));
      expect(config['proxy-groups'], isNotEmpty);
    });

    test('recognizes base64-encoded Clash YAML and keeps provider rules', () {
      final encoded = base64Encode(utf8.encode(_clashYaml));
      final parsed = parseSubscription(encoded);
      expect(parsed.clashConfig, isNotNull);

      final config = baseConfigFor(parsed);
      expect(config['rules'], contains('DOMAIN-SUFFIX,example.com,PROXY'));
      expect(config['rules'], contains('MATCH,PROXY'));
    });
  });
}
