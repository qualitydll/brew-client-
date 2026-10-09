import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/android_vpn.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/dev.brew.brew/vpn');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('start timeout cleans up only its own session', () async {
    final pendingStart = Completer<Object?>();
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'startVpn' &&
          (call.arguments as Map)['sessionId'] == 'old-session') {
        return pendingStart.future;
      }
      return null;
    });
    final vpn = AndroidVpn(
      channel: channel,
      startTimeout: const Duration(milliseconds: 20),
      stopTimeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      vpn.start('old/config.yaml', sessionId: 'old-session'),
      throwsA(isA<TimeoutException>()),
    );
    await vpn.start('new/config.yaml', sessionId: 'new-session');
    pendingStart.complete(null);
    await Future<void>.delayed(Duration.zero);

    expect(
      calls.map((call) => call.method).toList(),
      ['startVpn', 'stopVpn', 'startVpn'],
    );
    expect((calls[1].arguments as Map)['sessionId'], 'old-session');
    expect((calls[2].arguments as Map)['sessionId'], 'new-session');
  });

  test('native start error also requests session-scoped cleanup', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'startVpn') {
        throw PlatformException(code: 'vpn_service_failed', message: 'bad config');
      }
      return null;
    });
    final vpn = AndroidVpn(
      channel: channel,
      startTimeout: const Duration(milliseconds: 20),
      stopTimeout: const Duration(milliseconds: 20),
    );

    await expectLater(
      vpn.start('profile/config.yaml', sessionId: 'failed-session'),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'vpn_service_failed',
        ),
      ),
    );

    expect(calls.map((call) => call.method).toList(), ['startVpn', 'stopVpn']);
    expect((calls[1].arguments as Map)['sessionId'], 'failed-session');
  });
}
