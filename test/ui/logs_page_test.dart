import 'package:brew/state/app_state.dart';
import 'package:brew/state/models.dart';
import 'package:brew/ui/pages/logs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('log messages use the full row width and wrap', (tester) async {
    tester.view.physicalSize = const Size(680, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState();
    addTearDown(state.dispose);
    state.logs.add(
      LogEntry('error', List.filled(24, 'connection-failed-').join()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppScope(state: state, child: const LogsPage()),
        ),
      ),
    );

    final message = tester.getSize(find.byType(SelectableText));
    expect(message.width, greaterThan(560));
    expect(message.height, greaterThan(30));
    expect(tester.takeException(), isNull);
  });
}
