import 'package:flutter/material.dart';

import '../core/themes/AppTheme.dart';
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
  required Stream<String> connectionStatusStream,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ColorMenu(
      colors: colors,
      onChanged: onChanged,
      connectionStatusStream: connectionStatusStream,
    ),
  );
}

class ColorMenu extends StatefulWidget {
  final ShiftColors colors;
  final ValueChanged<ShiftColors> onChanged;
  final Stream<String> connectionStatusStream;

  const ColorMenu({
    super.key,
    required this.colors,
    required this.onChanged,
    required this.connectionStatusStream,
  });

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
                        'COLOR CONFIGURATION',
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
                  TextButton(
                    onPressed: () => update(const ShiftColors()),
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
          Text(label, style: AppTheme.labelStyle),
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
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c,
                      ),
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
