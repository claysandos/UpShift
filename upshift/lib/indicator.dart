import 'dart:math' as math;
import 'package:flutter/material.dart';

// Colors for the shift-light states
class ShiftPalette {
  static const green = Color(0xFF22D66B);
  static const amber = Color(0xFFFFD11A);
  static const red = Color(0xFFFF2D2D);
  static const flashBlue = Color(0xFF4DA3FF);
  static const flashWhite = Color(0xFFFFFFFF);
}

// Where the color starts changing, where it hits full red, and where it flashes
class ShiftConfig {
  // Green until this RPM
  final double startRpm;
  // Red above this RPM (shift now)
  final double shiftRpm;
  // Flashing at this RPM (redline)
  final double redlineRpm;
  // Set initial shift config RPMs
  const ShiftConfig({
    this.startRpm = 1500,
    this.shiftRpm = 3000,
    this.redlineRpm = 4500,
  });

  // 0.0 at startRpm, 1.0 at shiftRpm
  double progress(double rpm) =>
      ((rpm - startRpm) / (shiftRpm - startRpm)).clamp(0.0, 1.0);

  // Green -> amber -> red as RPM climbs
  Color colorFor(double rpm) {
    final t = progress(rpm);
    if (t < 0.6) {
      return Color.lerp(ShiftPalette.green, ShiftPalette.amber, t / 0.6)!;
    }
    return Color.lerp(ShiftPalette.amber, ShiftPalette.red, (t - 0.6) / 0.4)!;
  }
}

// The SS badge. Pass the live RPM; outline + glow follow the shift color
class SsBadge extends StatefulWidget {
  final double rpm;
  final ShiftConfig config;
  final Color letterColor;

  const SsBadge({
    super.key,
    required this.rpm,
    this.config = const ShiftConfig(),
    this.letterColor = const Color(0xFFF2F4F7),
  });

  @override
  State<SsBadge> createState() => _SsBadgeState();
}

class _SsBadgeState extends State<SsBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
  );

  bool get _overRedline => widget.rpm >= widget.config.redlineRpm;

  @override
  void didUpdateWidget(SsBadge old) {
    super.didUpdateWidget(old);
    if (_overRedline && !_flash.isAnimating) {
      _flash.repeat(reverse: true);
    } else if (!_overRedline && _flash.isAnimating) {
      _flash.stop();
      _flash.value = 0;
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.config.progress(widget.rpm);
    final base = widget.config.colorFor(widget.rpm);
    // Glow gets bigger as RPM climbs, so it isn't color-only feedback
    final glow = _overRedline ? 1.0 : 0.25 + 0.75 * t;

    // Smooth the color between RPM updates
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: base),
      duration: const Duration(milliseconds: 90),
      builder: (context, smoothed, _) {
        return AnimatedBuilder(
          animation: _flash,
          builder: (context, _) {
            final color = _overRedline
                ? Color.lerp(
                ShiftPalette.flashBlue, ShiftPalette.flashWhite, _flash.value)!
                : (smoothed ?? base);
            return CustomPaint(
              painter: _SsPainter(
                color: color,
                glow: glow,
                letterColor: widget.letterColor,
              ),
              size: Size.infinite,
            );
          },
        );
      },
    );
  }
}

class _SsPainter extends CustomPainter {
  final Color color;
  // 0..1
  final double glow;
  final Color letterColor;

  _SsPainter({
    required this.color,
    required this.glow,
    required this.letterColor,
  });

  // One boxy S on a 100 x 140 grid
  static const _points = <Offset>[
    Offset(0, 0), Offset(82, 0), Offset(100, 22), Offset(100, 30),
    Offset(30, 30), Offset(30, 48), Offset(36, 54), Offset(100, 54),
    Offset(100, 140), Offset(18, 140), Offset(0, 118), Offset(0, 110),
    Offset(70, 110), Offset(70, 92), Offset(64, 86), Offset(0, 86),
  ];

  static Path _s(double dx) {
    final p = Path()..moveTo(_points.first.dx + dx, _points.first.dy);
    for (final pt in _points.skip(1)) {
      p.lineTo(pt.dx + dx, pt.dy);
    }
    return p..close();
  }

  // Two S's side by side: 218 x 140
  static final Path _letters = Path()
    ..addPath(_s(0), Offset.zero)
    ..addPath(_s(118), Offset.zero);

  @override
  void paint(Canvas canvas, Size size) {
    // Pad leaves room for the glow
    const w = 218.0, h = 140.0, pad = 56.0;
    final scale = math.min(size.width / (w + pad), size.height / (h + pad));

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    // Lean forward
    canvas.transform(Matrix4.skewX(-16 * math.pi / 180).storage);
    canvas.scale(scale);
    canvas.translate(-w / 2, -h / 2);

    // Soft glow behind the letters (two blur passes)
    for (final pass in [
      (sigma: 6 + 26 * glow, alpha: 0.35 + 0.35 * glow),
      (sigma: 3 + 8 * glow, alpha: 0.5 + 0.4 * glow),
    ]) {
      canvas.drawPath(
        _letters,
        Paint()
          ..color = color.withAlpha((pass.alpha * 255).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeJoin = StrokeJoin.miter
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, pass.sigma),
      );
    }

    // Outline (drawn first so the fill covers its inner half), then the fill
    canvas.drawPath(
      _letters,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeJoin = StrokeJoin.miter,
    );
    canvas.drawPath(_letters, Paint()..color = letterColor);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SsPainter old) =>
      old.color != color || old.glow != glow || old.letterColor != letterColor;
}