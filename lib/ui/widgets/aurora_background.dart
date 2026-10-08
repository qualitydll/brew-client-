import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion.dart';

/// Slowly drifting, color-tinted light blobs behind the whole UI.
/// Becomes livelier and brighter while connected.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.energized});

  final bool energized;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraState extends ChangeNotifier {
  double time = 0;
  double energy = 0;
  void tick() => notifyListeners();
}

class _AuroraBackgroundState extends State<AuroraBackground> {
  final _s = _AuroraState();
  final _clock = Ambient.instance;

  @override
  void initState() {
    super.initState();
    if (!Motion.disabled('aurora')) {
      _clock
        ..addListener(_tick)
        ..retain();
    }
  }

  void _tick() {
    final dt = _clock.dt;
    _s.energy +=
        ((widget.energized ? 1.0 : 0.0) - _s.energy) *
        (1 - math.exp(-dt * 1.5));
    _s.time += dt * (0.25 + 0.55 * _s.energy);
    _s.tick();
  }

  @override
  void dispose() {
    if (!Motion.disabled('aurora')) {
      _clock
        ..removeListener(_tick)
        ..release();
    }
    _s.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _AuroraPainter(_s, Theme.of(context).colorScheme),
        size: Size.infinite,
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.s, this.scheme) : super(repaint: s);

  final _AuroraState s;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = scheme.surface);
    final dark = scheme.brightness == Brightness.dark;
    final blobs = [
      (scheme.primary, 0.0, 0.31, 0.23, 0.75, 0.25),
      (scheme.tertiary, 2.1, 0.19, 0.29, 0.25, 0.8),
      (scheme.secondary, 4.2, 0.27, 0.17, 0.85, 0.85),
      (scheme.primaryContainer, 1.3, 0.13, 0.21, 0.2, 0.2),
    ];
    final t = s.time;
    final base = size.shortestSide;
    final alpha = (dark ? 0.14 : 0.18) + (dark ? 0.12 : 0.1) * s.energy;
    final paint = Paint()..color = Colors.black.withValues(alpha: alpha);
    for (final (color, phase, fx, fy, cx, cy) in blobs) {
      final center = Offset(
        size.width * (cx + 0.18 * math.sin(t * fx * 3 + phase)),
        size.height * (cy + 0.16 * math.cos(t * fy * 3 + phase * 1.3)),
      );
      final radius =
          base *
          (0.55 + 0.1 * math.sin(t * 0.7 + phase)) *
          (1 + 0.2 * s.energy);
      paint.shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.scheme != scheme;
}
