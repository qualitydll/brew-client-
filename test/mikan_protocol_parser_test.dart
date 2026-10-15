import 'package:flutter_test/flutter_test.dart';
import 'package:brew/core/link_parser.dart';

void main() {
  group('Mikan/Mihomo share-link compatibility', () {
    test('parses AnyTLS links into a Mihomo proxy', () {
      final proxy = parseLink(
        'anytls://secret@example.com:8443?sni=cdn.example.com&insecure=1#Mikan%20AnyTLS',
      );

      expect(proxy, isNotNull);
      expect(proxy!['type'], 'anytls');
      expect(proxy['name'], 'Mikan AnyTLS');
      expect(proxy['server'], 'example.com');
      expect(proxy['port'], 8443);
      expect(proxy['password'], 'secret');
      expect(proxy['sni'], 'cdn.example.com');
      expect(proxy['skip-cert-verify'], isTrue);
      expect(proxy['udp'], isTrue);
    });

    test('preserves VLESS encryption parameters for PQ profiles', () {
      final proxy = parseLink(
        'vless://user-id@example.com:443?security=reality&encryption=mlkem768x25519plus.native%2Fxorpub%2Frandom.1rtt&pbk=public-key&sid=abcd&type=tcp#Mikan%20PQ',
      );

      expect(proxy, isNotNull);
      expect(proxy!['type'], 'vless');
      expect(proxy['encryption'], 'mlkem768x25519plus.native/xorpub/random.1rtt');
      expect(proxy['reality-opts']['public-key'], 'public-key');
      expect(proxy['reality-opts']['short-id'], 'abcd');
    });
  });
}
