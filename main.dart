import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'brand.dart';
import 'state/app_state.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

bool get isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.init();

  if (isDesktop) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1180, 760),
      minimumSize: Size(920, 640),
      center: true,
      title: kAppName,
      titleBarStyle: TitleBarStyle.hidden,
      backgroundColor: Colors.transparent,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    await windowManager.setPreventClose(true);
    windowManager.addListener(_CloseHandler(state));
  }

  runApp(BrewApp(state: state));
}

class _CloseHandler with WindowListener {
  _CloseHandler(this.state);
  final AppState state;

  @override
  Future<void> onWindowClose() async {
    await state.shutdown();
    await windowManager.destroy();
  }
}

class BrewApp extends StatelessWidget {
  const BrewApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            final s = state.settings;
            final seed = s.systemColor
                ? lightDynamic?.primary ?? kBrewOrange
                : s.seedColor;
            ColorScheme scheme(Brightness b) =>
                brewScheme(seed, b, s.schemeVariant);
            return MaterialApp(
              title: kAppName,
              debugShowCheckedModeBanner: false,
              themeMode: s.themeMode,
              theme: buildTheme(scheme(Brightness.light)),
              darkTheme: buildTheme(scheme(Brightness.dark)),
              themeAnimationDuration: const Duration(milliseconds: 500),
              themeAnimationCurve: Curves.easeInOutCubic,
              home: const Shell(),
            );
          },
        ),
      ),
    );
  }
}
