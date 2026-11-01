import 'package:flutter/material.dart';

import 'indicator.dart';

// Slider limits and the smallest gap allowed between two shift points
const minRpm = 1000.0;
const maxRpm = 8000.0;
const minGap = 300.0;

// Opens the shift point menu as a bottom sheet
Future<void> showShiftMenu(
    BuildContext context, {
      required ShiftConfig config,
      required ValueChanged<ShiftConfig> onChanged,
    }) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF14181D),
    builder: (_) => ShiftMenu(config: config, onChanged: onChanged),
  );
}

// 3500 -> "3,500"
String fmt(double v) => v
    .round()
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

class ShiftMenu extends StatefulWidget {
  final ShiftConfig config;
  final ValueChanged<ShiftConfig> onChanged;
  const ShiftMenu({super.key, required this.config, required this.onChanged});

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
    // Each point stays at least minGap away from its neighbours
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shift Indicator Configuration',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 4),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => update(const ShiftConfig()),
              child: const Text('Reset to defaults'),
            ),
          ],
        ),
      ),
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
              Flexible(
                child: Text(label,
                    style: const TextStyle(color: Color(0xFF9AA3AF))),
              ),
              Text('${fmt(v)} RPM',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          Slider(
            min: lo,
            max: hi,
            divisions: ((hi - lo) / 100).round().clamp(1, 1000),
            value: v,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}