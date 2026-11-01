import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// Colors for the shift-light states
class ShiftPalette {
  static const green = Color(0xFF22D66B);
  static const amber = Color(0xFFFFD11A);
  static const red = Color(0xFFFF2D2D);
  static const white = Color(0xFFFFFFFF);
}

// The colors the user can change in the color menu
class ShiftColors {
  // Cruise / start of the climb (default green)
  final Color low;
  // Middle of the climb (default amber)
  final Color mid;
  // Shift now (default red)
  final Color shift;
  // Redline strobe alternates between these two (default white / red).
  // redlineA is also the color the outline fades to during the shift stage.
  final Color redlineA;
  final Color redlineB;

  const ShiftColors({
    this.low = ShiftPalette.green,
    this.mid = ShiftPalette.amber,
    this.shift = ShiftPalette.red,
    this.redlineA = ShiftPalette.white,
    this.redlineB = ShiftPalette.red,
  });

  ShiftColors copyWith({
    Color? low,
    Color? mid,
    Color? shift,
    Color? redlineA,
    Color? redlineB,
  }) =>
      ShiftColors(
        low: low ?? this.low,
        mid: mid ?? this.mid,
        shift: shift ?? this.shift,
        redlineA: redlineA ?? this.redlineA,
        redlineB: redlineB ?? this.redlineB,
      );
}

/// RPM Threshold Stages
/// 0 Cruise - .. CruiseRPM - Solid green
/// 1 Approach - CruiseRPM .. ShiftRPM - Green to yellow to red
/// 2 Shift Now - ShiftRPM .. RedlineRPM - Red, outline fades to white, glow pulses
/// 3 redline - RedlineRPM .. - Red and white strobe
///
/// A stage is held until RPM drops [hysteresis] below its threshold,
/// so it doesn't flicker when RPM hovers right at a threshold.

// Where the color starts changing, where it hits full red, and where it flashes
class ShiftConfig {
  // Green until this RPM
  final double cruiseRpm;
  // Red with white outline at this RPM (shift)
  final double shiftRpm;
  // Red with white flashing at this RPM (redline)
  final double redlineRpm;
  // RPM drop needed below a threshold before leaving that stage
  final double hysteresis;
  // Set initial shift config RPMs
  const ShiftConfig({
    this.cruiseRpm = 2000,
    this.shiftRpm = 3500,
    this.redlineRpm = 5000,
    this.hysteresis = 200,
  });

  ShiftConfig copyWith({
    double? cruiseRpm,
    double? shiftRpm,
    double? redlineRpm,
    double? hysteresis,
  }) =>
      ShiftConfig(
        cruiseRpm: cruiseRpm ?? this.cruiseRpm,
        shiftRpm: shiftRpm ?? this.shiftRpm,
        redlineRpm: redlineRpm ?? this.redlineRpm,
        hysteresis: hysteresis ?? this.hysteresis,
      );

  // 0.0 at cruiseRpm, 1.0 at shiftRpm
  double progress(double rpm) =>
      ((rpm - cruiseRpm) / (shiftRpm - cruiseRpm)).clamp(0.0, 1.0);

  // low -> mid -> shift color as RPM climbs
  Color colorFor(double rpm, ShiftColors colors) {
    final t = progress(rpm);
    if (t < 0.6) return Color.lerp(colors.low, colors.mid, t / 0.6)!;
    return Color.lerp(colors.mid, colors.shift, (t - 0.6) / 0.4)!;
  }
}

// The SS badge. Pass the live RPM and it animates through the four stages
class SsBadge extends StatefulWidget {
  final double rpm;
  final ShiftConfig config;
  // Colors for each stage (see ShiftColors)
  final ShiftColors colors;
  // Slower redline strobe (about 1 per second) and no background flash
  final bool reduceFlashing;
  // Also used as the inside of the letters unless filledLetters is true
  final Color background;
  // false: hollow letters, the outline carries the color
  // true: letters are filled with the color, outline is a darker shade
  final bool filledLetters;

  const SsBadge({
    super.key,
    required this.rpm,
    this.config = const ShiftConfig(),
    this.colors = const ShiftColors(),
    this.reduceFlashing = false,
    this.background = const Color(0xFF0B0D10),
    this.filledLetters = false,
  });

  @override
  State<SsBadge> createState() => SsBadgeState();
}

class SsBadgeState extends State<SsBadge> with SingleTickerProviderStateMixin {
  late final Ticker ticker;
  Duration elapsed = Duration.zero;
  // When the current shift stage began (drives the outline fade and pulse)
  Duration? shiftT0;
  int stage = 0;
  // Eased toward the real RPM so colors glide between updates
  late double displayRpm;

  @override
  void initState() {
    super.initState();
    displayRpm = widget.rpm;
    updateStage();
    ticker = createTicker(onTick)..start();
  }

  @override
  void didUpdateWidget(SsBadge old) {
    super.didUpdateWidget(old);
    updateStage();
  }

  void updateStage() {
    final c = widget.config;
    final rpm = widget.rpm;
    final th = [0.0, c.cruiseRpm, c.shiftRpm, c.redlineRpm];
    final up = rpm >= c.redlineRpm
        ? 3
        : rpm >= c.shiftRpm
        ? 2
        : rpm >= c.cruiseRpm
        ? 1
        : 0;
    if (up > stage) stage = up;
    while (stage > 0 && rpm < th[stage] - c.hysteresis) {
      stage--;
    }
  }

  void onTick(Duration d) {
    setState(() {
      elapsed = d;
      displayRpm += (widget.rpm - displayRpm) * 0.3;
      if (stage >= 2) {
        shiftT0 ??= d;
      } else {
        shiftT0 = null;
      }
    });
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final t = c.progress(displayRpm);
    final inShiftMs =
    shiftT0 == null ? 0 : (elapsed - shiftT0!).inMilliseconds;

    // statusColor is the green -> red color for the current stage
    final colors = widget.colors;
    var statusColor = colors.low;
    var glow = 0.3;
    var scale = 1.0;
    var bg = widget.background;
    var strobeOn = false;

    if (stage == 1) {
      statusColor = c.colorFor(displayRpm, colors);
      glow = 0.3 + 0.5 * t;
    } else if (stage == 2) {
      // 2 pulses per second
      final p = 0.5 + 0.5 * math.sin(inShiftMs / 1000 * math.pi * 4);
      statusColor = colors.shift;
      glow = 0.35 + 0.65 * p;
      scale = 1 + 0.04 * p;
    } else if (stage == 3) {
      // About 10 flashes per second (or 1 per second if reduceFlashing)
      final half = widget.reduceFlashing ? 250 : 50;
      strobeOn = (elapsed.inMilliseconds ~/ half) % 2 == 0;
      statusColor = strobeOn ? colors.redlineA : colors.redlineB;
      glow = 1;
      if (!widget.reduceFlashing && strobeOn) {
        bg = Color.lerp(widget.background, colors.redlineB, 0.28)!;
      }
    }

    // Outline fades slowly to white (1.4 s) once the shift stage begins
    final w = (inShiftMs / 1400).clamp(0.0, 1.0);
    final Color fill;
    final Color outline;
    if (widget.filledLetters) {
      fill = statusColor;
      outline = stage == 3
          ? (strobeOn ? colors.redlineB : colors.redlineA)
          : Color.lerp(Color.lerp(statusColor, Colors.black, 0.45)!,
          colors.redlineA, w)!;
    } else {
      fill = widget.background;
      outline = stage == 3
          ? statusColor
          : Color.lerp(statusColor, colors.redlineA, w)!;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: CustomPaint(
        size: Size.infinite,
        painter: SsPainter(
          fill: fill,
          outline: outline,
          glowColor: statusColor,
          glow: glow,
          scale: scale,
        ),
      ),
    );
  }
}

class SsPainter extends CustomPainter {
  final Color fill;
  final Color outline;
  final Color glowColor;
  // 0..1
  final double glow;
  final double scale;

  SsPainter({
    required this.fill,
    required this.outline,
    required this.glowColor,
    required this.glow,
    required this.scale,
  });

  // One boxy S on a 100 x 140 grid
  static const points = <Offset>[
    Offset(0, 0), Offset(82, 0), Offset(100, 22), Offset(100, 30),
    Offset(30, 30), Offset(30, 48), Offset(36, 54), Offset(100, 54),
    Offset(100, 140), Offset(18, 140), Offset(0, 118), Offset(0, 110),
    Offset(70, 110), Offset(70, 92), Offset(64, 86), Offset(0, 86),
  ];

  static Path s(double dx) {
    final p = Path()..moveTo(points.first.dx + dx, points.first.dy);
    for (final pt in points.skip(1)) {
      p.lineTo(pt.dx + dx, pt.dy);
    }
    return p..close();
  }

  // Two S's side by side: 218 x 140
  static final Path letters = Path()
    ..addPath(s(0), Offset.zero)
    ..addPath(s(118), Offset.zero);

  @override
  void paint(Canvas canvas, Size size) {
    // Pad leaves room for the glow
    const w = 218.0, h = 140.0, pad = 56.0;
    final fit = math.min(size.width / (w + pad), size.height / (h + pad));

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    // Lean forward
    canvas.transform(Matrix4.skewX(-16 * math.pi / 180).storage);
    canvas.scale(fit * scale);
    canvas.translate(-w / 2, -h / 2);

    // Soft glow behind the letters (two blur passes)
    for (final pass in [
      (sigma: 6 + 26 * glow, alpha: 0.35 + 0.35 * glow),
      (sigma: 3 + 8 * glow, alpha: 0.5 + 0.4 * glow),
    ]) {
      canvas.drawPath(
        letters,
        Paint()
          ..color = glowColor.withAlpha((pass.alpha * 255).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeJoin = StrokeJoin.miter
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, pass.sigma),
      );
    }

    // Outline (drawn first so the fill covers its inner half), then the fill
    canvas.drawPath(
      letters,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeJoin = StrokeJoin.miter,
    );
    canvas.drawPath(letters, Paint()..color = fill);

    canvas.restore();
  }

  @override
  bool shouldRepaint(SsPainter old) =>
      old.fill != fill ||
          old.outline != outline ||
          old.glowColor != glowColor ||
          old.glow != glow ||
          old.scale != scale;
}