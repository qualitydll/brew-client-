import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../motion.dart';

import '../../state/models.dart';

/// The hero connect button: an M3 Expressive-style shape that morphs between
/// a scalloped "cookie" (idle), a wobbling blob (connecting) and a breathing
/// circle with ripples (connected).
class ConnectOrb extends StatefulWidget {
  const ConnectOrb({
    super.key,
    required this.status,
    required this.onTap,
    this.size = 248,
    this.enabled = true,
  });

  final ConnStatus status;
  final VoidCallback onTap;
  final double size;
  final bool enabled;

  @override
  State<ConnectOrb> createState() => _ConnectOrbState();
}

class _OrbParams extends ChangeNotifier {
  double time = 0;
  double spin = 0;
  double scallop = 0.075;
  double wobble = 0;
  double connected = 0;
  double press = 0;
  double hover = 0;
  double rings = 0;

  void tick() => notifyListeners();
}

class _ConnectOrbState extends State<ConnectOrb>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _p = _OrbParams();
  final _clock = Ambient.instance;
  final _off = Motion.disabled('orb');
  Duration _last = Duration.zero;
  double _spinSpeed = 0.15;
  bool _hovered = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    if (!_off) {
      _clock
        ..addListener(_onAmbient)
        ..retain();
      _kick();
    }
  }

  @override
  void didUpdateWidget(ConnectOrb old) {
    super.didUpdateWidget(old);
    if (old.status != widget.status) _kick();
  }

  /// Switch to full frame rate until the shape settles.
  void _kick() {
    if (_off || _ticker.isActive) return;
    _last = Duration.zero;
    _ticker.start();
  }

  void _onAmbient() {
    if (!_ticker.isActive) _step(_clock.dt);
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    if (_step(dt)) _ticker.stop();
  }

  /// Advances the animation; returns true when only ambient motion remains.
  bool _step(double dt) {
    double approach(double v, double target, double k) =>
        v + (target - v) * (1 - math.exp(-dt * k));

    final s = widget.status;
    final busy = s == ConnStatus.connecting || s == ConnStatus.disconnecting;
    final on = s == ConnStatus.connected;

    final targetScallop =
        (on ? 0.0 : (busy ? 0.03 : 0.075)) + (_hovered && !on ? 0.025 : 0);
    final targetWobble = busy ? 0.09 : 0.0;
    final targetSpeed = busy ? 2.4 : (on ? 0.0 : 0.15);
    final targetOn = on ? 1.0 : 0.0;
    final targetPress = _pressed ? 1.0 : 0.0;
    final targetHover = _hovered ? 1.0 : 0.0;

    _p.time += dt;
    _spinSpeed = approach(_spinSpeed, targetSpeed, 3);
    _p.spin += dt * _spinSpeed;
    _p.scallop = approach(_p.scallop, targetScallop, 7);
    _p.wobble = approach(_p.wobble, targetWobble, 5);
    _p.connected = approach(_p.connected, targetOn, 4);
    _p.press = approach(_p.press, targetPress, 18);
    _p.hover = approach(_p.hover, targetHover, 10);
    _p.rings = approach(_p.rings, targetOn, 2);
    _p.tick();

    bool near(double a, double b) => (a - b).abs() < 0.004;
    return !busy &&
        near(_spinSpeed, targetSpeed) &&
        near(_p.scallop, targetScallop) &&
        near(_p.wobble, targetWobble) &&
        near(_p.connected, targetOn) &&
        near(_p.press, targetPress) &&
        near(_p.hover, targetHover) &&
        near(_p.rings, targetOn);
  }

  @override
  void dispose() {
    if (!_off) {
      _clock
        ..removeListener(_onAmbient)
        ..release();
    }
    _ticker.dispose();
    _p.dispose();
    super.dispose();
  }

  IconData get _icon => switch (widget.status) {
    ConnStatus.disconnected => Icons.power_settings_new_rounded,
    ConnStatus.connecting ||
    ConnStatus.disconnecting => Icons.more_horiz_rounded,
    ConnStatus.connected => Icons.shield_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = widget.size;
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) {
        _hovered = true;
        _kick();
      },
      onExit: (_) {
        _hovered = false;
        _kick();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (_) {
          _pressed = true;
          _kick();
        },
        onTapCancel: () {
          _pressed = false;
          _kick();
        },
        onTapUp: (_) {
          _pressed = false;
          _kick();
        },
        onTap: widget.enabled ? widget.onTap : null,
        child: SizedBox(
          width: size * 1.7,
          height: size * 1.7,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _OrbPainter(_p, scheme, widget.enabled),
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: _p,
                builder: (context, child) {
                  final fg = Color.lerp(
                    scheme.primary,
                    scheme.onPrimary,
                    _p.connected,
                  )!;
                  return Transform.scale(
                    scale: 1 - _p.press * 0.06 + _p.hover * 0.03,
                    child: IconTheme(
                      data: IconThemeData(
                        color: widget.enabled ? fg : scheme.outline,
                        size: size * 0.3,
                      ),
                      child: child!,
                    ),
                  );
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 450),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: anim,
                    child: RotationTransition(
                      turns: Tween(begin: -0.15, end: 0.0).animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                  ),
                  child: Icon(_icon, key: ValueKey(_icon)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.p, this.scheme, this.enabled) : super(repaint: p);

  final _OrbParams p;
  final ColorScheme scheme;
  final bool enabled;

  Path _shape(Offset c, double r) {
    const steps = 180;
    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final t = i / steps * math.pi * 2;
      final k =
          1 +
          p.scallop * math.cos(9 * (t + p.spin)) +
          p.wobble * math.sin(3 * t + p.time * 3.1) +
          p.wobble * 0.6 * math.cos(5 * t - p.time * 2.3);
      final pt = c + Offset(math.cos(t), math.sin(t)) * (r * k);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final base = size.shortestSide / 1.7 / 2;
    final breathe = 1 + 0.025 * p.connected * math.sin(p.time * 2.2);
    final r = base * breathe * (1 - p.press * 0.06 + p.hover * 0.03);

    // Ripple rings when connected.
    if (p.rings > 0.01) {
      for (var i = 0; i < 3; i++) {
        final phase = ((p.time / 2.6) + i / 3) % 1.0;
        final ringR = math.min(r * (1 + phase * 0.62), base * 1.62);
        final alpha = (1 - phase) * 0.45 * p.rings;
        canvas.drawPath(
          Path()..addOval(Rect.fromCircle(center: c, radius: ringR)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 + (1 - phase) * 3
            ..color = scheme.primary.withValues(alpha: alpha),
        );
      }
    }

    // Glow: cached unit radial gradient, alpha via paint.
    final glowAlpha = 0.22 + 0.33 * p.connected + 0.1 * p.hover;
    final glowColor = enabled ? scheme.primary : scheme.outline;
    final glowR = math.min(r * (1.45 + 0.15 * p.connected), base * 1.66);
    final glowRect = Rect.fromCircle(center: c, radius: glowR.roundToDouble());
    canvas.drawCircle(
      c,
      glowRect.width / 2,
      Paint()
        ..color = Colors.black.withValues(alpha: glowAlpha.clamp(0.0, 1.0))
        ..shader = _glowShader(glowColor, glowRect),
    );

    final shape = _shape(c, r);
    final fill = Paint();
    if (enabled) {
      fill.shader = _fillShader(
        Rect.fromCircle(center: c, radius: base * 1.15),
      );
    } else {
      fill.color = scheme.surfaceContainerHighest;
    }
    canvas.drawPath(shape, fill);

    // Inner highlight ring for depth.
    canvas.drawPath(
      _shape(c, r * 0.84),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Color.lerp(
          scheme.primary,
          scheme.onPrimary,
          p.connected,
        )!.withValues(alpha: 0.18),
    );
  }

  static final _cache = <Object, Shader>{};

  Shader _glowShader(Color color, Rect rect) {
    if (_cache.length > 128) _cache.clear();
    return _cache.putIfAbsent(
      ('glow', color.toARGB32(), rect),
      () => RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
        stops: const [0.55, 1],
      ).createShader(rect),
    );
  }

  Shader _fillShader(Rect rect) {
    final q = (p.connected * 40).round() / 40;
    final idle = scheme.primaryContainer;
    final from = Color.lerp(idle, scheme.primary, q)!;
    final to = Color.lerp(
      Color.lerp(idle, scheme.secondaryContainer, 0.5)!,
      scheme.tertiary,
      q,
    )!;
    return _cache.putIfAbsent(
      ('fill', from.toARGB32(), to.toARGB32(), rect),
      () => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [from, to],
      ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.scheme != scheme || old.enabled != enabled;
}
