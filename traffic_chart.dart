import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../motion.dart';

import '../../state/app_state.dart';

/// Smoothly scrolling dual-line speed chart.
class TrafficChart extends StatefulWidget {
  const TrafficChart({super.key, required this.store});

  final TrafficStore store;

  @override
  State<TrafficChart> createState() => _TrafficChartState();
}

class _ChartState extends ChangeNotifier {
  double progress = 1;
  double maxValue = 1024;
  void tick() => notifyListeners();
}

class _TrafficChartState extends State<TrafficChart>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _s = _ChartState();
  final _off = Motion.disabled('chart');
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    widget.store.addListener(_onSample);
  }

  @override
  void didUpdateWidget(TrafficChart old) {
    super.didUpdateWidget(old);
    if (old.store != widget.store) {
      old.store.removeListener(_onSample);
      widget.store.addListener(_onSample);
    }
  }

  void _onSample() {
    if (_off) {
      _s.progress = 1;
      _s.tick();
      return;
    }
    if (_ticker.isActive) return;
    _last = Duration.zero;
    _ticker.start();
  }

  /// Animates the scroll after each sample, then idles until the next one.
  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    final since =
        DateTime.now().difference(widget.store.lastSample).inMilliseconds /
        1000;
    _s.progress = Curves.easeOut.transform(since.clamp(0.0, 1.0));
    final peak = [
      ...widget.store.up,
      ...widget.store.down,
    ].fold<int>(0, math.max).toDouble();
    final target = math.max(peak * 1.25, 16 * 1024.0);
    _s.maxValue += (target - _s.maxValue) * (1 - math.exp(-dt * 3));
    _s.tick();
    if (since >= 1 && (target - _s.maxValue).abs() < target * 0.01) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_onSample);
    _ticker.dispose();
    _s.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ChartPainter(_s, widget.store, scheme),
        size: Size.infinite,
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.s, this.store, this.scheme) : super(repaint: s);

  final _ChartState s;
  final TrafficStore store;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _series(canvas, size, store.up.toList(), scheme.tertiary);
    _series(canvas, size, store.down.toList(), scheme.primary);
    canvas.restore();
  }

  void _series(Canvas canvas, Size size, List<int> values, Color color) {
    final n = values.length;
    final dx = size.width / (n - 2);
    final shift = s.progress * dx;
    Offset pt(int i) {
      final v = values[i] / s.maxValue;
      return Offset(
        i * dx - shift,
        size.height - v.clamp(0.0, 1.0) * size.height * 0.92 - 2,
      );
    }

    final path = Path();
    var prev = pt(0);
    path.moveTo(prev.dx, prev.dy);
    for (var i = 1; i < n; i++) {
      final cur = pt(i);
      final mx = (prev.dx + cur.dx) / 2;
      path.cubicTo(mx, prev.dy, mx, cur.dy, cur.dx, cur.dy);
      prev = cur;
    }
    final fill = Path.from(path)
      ..lineTo(prev.dx, size.height)
      ..lineTo(pt(0).dx, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..shader = _fillShader(color, size));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  static final _cache = <Object, Shader>{};

  static Shader _fillShader(Color color, Size size) {
    if (_cache.length > 32) _cache.clear();
    return _cache.putIfAbsent(
      (color.toARGB32(), size),
      () => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0)],
      ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.scheme != scheme;
}
