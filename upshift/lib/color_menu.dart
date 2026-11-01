import 'package:flutter/material.dart';

import 'indicator.dart';

// Preset swatches offered for every color
const swatches = <Color>[
  Color(0xFF22D66B), // green
  Color(0xFF00D1C1), // teal
  Color(0xFF4DA3FF), // blue
  Color(0xFFA06BFF), // purple
  Color(0xFFFF3DF2), // magenta
  Color(0xFFFF2D2D), // red
  Color(0xFFFF5A1F), // orange
  Color(0xFFFFD11A), // amber
  Color(0xFFFFFFFF), // white
];

// Opens the color menu as a bottom sheet
Future<void> showColorMenu(
    BuildContext context, {
      required ShiftColors colors,
      required ValueChanged<ShiftColors> onChanged,
    }) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF14181D),
    builder: (_) => ColorMenu(colors: colors, onChanged: onChanged),
  );
}

class ColorMenu extends StatefulWidget {
  final ShiftColors colors;
  final ValueChanged<ShiftColors> onChanged;
  const ColorMenu({super.key, required this.colors, required this.onChanged});

  @override
  State<ColorMenu> createState() => ColorMenuState();
}

class ColorMenuState extends State<ColorMenu> {
  late ShiftColors colors = widget.colors;

  void update(ShiftColors c) {
    setState(() => colors = c);
    widget.onChanged(c);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shift colors',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ColorRow(
              label: 'Low RPM',
              selected: colors.low,
              onPick: (c) => update(colors.copyWith(low: c)),
            ),
            ColorRow(
              label: 'Mid RPM',
              selected: colors.mid,
              onPick: (c) => update(colors.copyWith(mid: c)),
            ),
            ColorRow(
              label: 'Shift RPM',
              selected: colors.shift,
              onPick: (c) => update(colors.copyWith(shift: c)),
            ),
            ColorRow(
              label: 'Shift RPM Outline + Redline RPM Flash 1',
              selected: colors.redlineA,
              onPick: (c) => update(colors.copyWith(redlineA: c)),
            ),
            ColorRow(
              label: 'Redline RPM Flash 2',
              selected: colors.redlineB,
              onPick: (c) => update(colors.copyWith(redlineB: c)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => update(const ShiftColors()),
              child: const Text('Reset to defaults'),
            ),
          ],
        ),
      ),
    );
  }
}

class ColorRow extends StatelessWidget {
  final String label;
  final Color selected;
  final ValueChanged<Color> onPick;
  const ColorRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF9AA3AF))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in swatches)
                GestureDetector(
                  onTap: () => onPick(c),
                  child: Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c.toARGB32() == selected.toARGB32()
                            ? Colors.white
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: c),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}