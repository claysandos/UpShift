import 'package:flutter/material.dart';

import 'indicator.dart';
import '../core/themes/AppTheme.dart';

// Slider limits and the smallest gap allowed between two shift points
const minRpm = 1000.0;
const maxRpm = 7000.0;
const minGap = 300.0;

// Opens the shift point menu as a bottom sheet
Future<void> showShiftMenu(
  BuildContext context, {
  required ShiftConfig config,
  required ValueChanged<ShiftConfig> onChanged,
  required Stream<String> connectionStatusStream,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ShiftMenu(
      config: config,
      onChanged: onChanged,
      connectionStatusStream: connectionStatusStream,
    ),
  );
}

// 3500 -> "3,500"
String fmt(double v) => v.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (m) => ',',
);

class ShiftMenu extends StatefulWidget {
  final ShiftConfig config;
  final ValueChanged<ShiftConfig> onChanged;
  final Stream<String> connectionStatusStream;

  const ShiftMenu({
    super.key,
    required this.config,
    required this.onChanged,
    required this.connectionStatusStream,
  });

  @override
  State<ShiftMenu> createState() => ShiftMenuState();
}

class ShiftMenuState extends State<ShiftMenu> {
  late ShiftConfig config = widget.config;

  void update(ShiftConfig c) {
    setState(() => config = c);
    widget.onChanged(c);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: widget.connectionStatusStream,
      initialData: 'Disconnected',
      builder: (context, connectionSnapshot) {
        final bool connected = connectionSnapshot.data == 'Connected';

        final Color cyanStatusColor = connected
            ? AppTheme.widgetCyanAccent
            : AppTheme.widgetCyanAccent.withValues(alpha: 0.3);

        // Each point stays at least minGap away from its neighbours
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.widgetBackground,
            border: Border.all(color: AppTheme.widgetBorder, width: 1.2),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: cyanStatusColor, blurRadius: 12)],
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(width: 4, height: 16, color: cyanStatusColor),
                      const SizedBox(width: 9),
                      Text(
                        'INDICATOR CONFIGURATION',
                        style: TextStyle(
                          color: cyanStatusColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  RpmSlider(
                    label: 'Cruise RPM',
                    value: config.cruiseRpm,
                    min: minRpm,
                    max: config.shiftRpm - minGap,
                    onChanged: (v) => update(config.copyWith(cruiseRpm: v)),
                  ),
                  RpmSlider(
                    label: 'Shift RPM',
                    value: config.shiftRpm,
                    min: config.cruiseRpm + minGap,
                    max: config.redlineRpm - minGap,
                    onChanged: (v) => update(config.copyWith(shiftRpm: v)),
                  ),
                  RpmSlider(
                    label: 'Redline RPM',
                    value: config.redlineRpm,
                    min: config.shiftRpm + minGap,
                    max: maxRpm,
                    onChanged: (v) => update(config.copyWith(redlineRpm: v)),
                  ),

                  TextButton(
                    onPressed: () => update(const ShiftConfig()),
                    child: Text(
                      'Reset to defaults',
                      style: AppTheme.clickableTextStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class RpmSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const RpmSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Snap to 100 RPM steps
    final lo = (min / 100).ceil() * 100.0;
    final hi = (max / 100).floor() * 100.0;
    final v = value.clamp(lo, hi).toDouble();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(label, style: AppTheme.labelStyle)),
              Text('${fmt(v)} RPM', style: AppTheme.unitStyle),
            ],
          ),
          Slider(
            min: lo,
            max: hi,
            divisions: ((hi - lo) / 100).round().clamp(1, 1000),
            value: v,
            onChanged: onChanged,
            activeColor: AppTheme.widgetBorder,
          ),
        ],
      ),
    );
  }
}
