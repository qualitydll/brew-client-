import 'package:brew/state/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile metadata stays unknown until the provider sends it', () {
    final profile = Profile(
      id: 'profile',
      name: 'Test',
      updatedAt: DateTime(2026),
    );

    expect(profile.hasTrafficInfo, isFalse);
    expect(profile.hasExpiryInfo, isFalse);
    expect(profile.usage, isNull);
    expect(profile.expire, isNull);

    profile.applyUserInfo('upload=100; download=300; total=1000; expire=0');

    expect(profile.hasTrafficInfo, isTrue);
    expect(profile.hasExpiryInfo, isTrue);
    expect(profile.used, 400);
    expect(profile.usage, 0.4);
    expect(profile.expire, isNull);
  });

  test('connection exposes its host, matched rule, and proxy chain', () {
    final connection = ProxyConnection.fromJson({
      'rule': 'DOMAIN-SUFFIX',
      'rulePayload': 'example.com',
      'chains': ['PROXY', 'Server 1'],
      'metadata': {
        'host': 'api.example.com',
        'destinationIP': '192.0.2.4',
        'destinationPort': '443',
        'network': 'tcp',
      },
    });

    expect(connection.host, 'api.example.com');
    expect(connection.port, '443');
    expect(connection.rule, 'DOMAIN-SUFFIX');
    expect(connection.rulePayload, 'example.com');
    expect(connection.chains, ['PROXY', 'Server 1']);
    expect(connection.network, 'tcp');
  });
}
