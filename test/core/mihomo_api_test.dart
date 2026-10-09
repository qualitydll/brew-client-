import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/mihomo_api.dart';

void main() {
  test('API readiness ends with a useful error after its deadline', () async {
    var attempts = 0;

    await expectLater(
      waitForMihomoApi(
        () async {
          attempts++;
          throw StateError('connection refused');
        },
        timeout: const Duration(milliseconds: 25),
        retryInterval: const Duration(milliseconds: 1),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('connection refused'),
        ),
      ),
    );

    expect(attempts, greaterThan(0));
  });
}
