import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// Debug switch for isolating animation cost: BREW_NO_ANIM=aurora,orb,chart|all
class Motion {
  static final _off = (Platform.environment['BREW_NO_ANIM'] ?? '')
      .split(',')
      .map((e) => e.trim())
      .toSet();

  static bool disabled(String name) =>
      _off.contains('all') || _off.contains(name);
}

/// Shared low-rate clock for idle "ambient" motion (background drift, idle orb).
/// Runs at [fps] while focused, slows down when the window loses focus and
/// stops entirely when minimized or when nobody listens.
class Ambient extends ChangeNotifier with WidgetsBindingObserver, WindowListener {
  Ambient._() {
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
      // Flutter lifecycle events alone do not reliably report a minimized
      // desktop window, so track native window focus as well.
      windowManager.isFocused().then((focused) {
        _windowFocused = focused;
        _sync();
      }).catchError((_) {});
    }
  }

  static final instance = Ambient._();

  static const fps = 30;
  static const unfocusedFps = 8;

  AppLifecycleState _life = AppLifecycleState.resumed;
  final _watch = Stopwatch()..start();
  Duration _last = Duration.zero;
  Timer? _timer;
  int _rate = 0;
  int _users = 0;
  bool _windowFocused = true;

  /// Seconds since previous tick (clamped).
  double dt = 0;

  void retain() {
    _users++;
    _sync();
  }

  void release() {
    _users--;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _life = state;
    _sync();
  }

  @override
  void onWindowBlur() {
    _windowFocused = false;
    _sync();
  }

  @override
  void onWindowFocus() {
    _windowFocused = true;
    _sync();
  }

  @override
  void onWindowMinimize() {
    _windowFocused = false;
    _sync();
  }

  @override
  void onWindowRestore() {
    windowManager.isFocused().then((focused) {
      _windowFocused = focused;
      _sync();
    }).catchError((_) {
      _windowFocused = true;
      _sync();
    });
  }

  void _sync() {
    final rate = _users <= 0 || !_windowFocused
        ? 0
        : switch (_life) {
            AppLifecycleState.resumed => fps,
            AppLifecycleState.inactive => unfocusedFps,
            _ => 0,
          };
    if (rate == _rate) return;
    _rate = rate;
    _timer?.cancel();
    _timer = null;
    if (rate == 0) return;
    _last = _watch.elapsed;
    _timer = Timer.periodic(Duration(microseconds: 1000000 ~/ rate), (_) {
      final now = _watch.elapsed;
      dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.15);
      _last = now;
      notifyListeners();
    });
  }
}
