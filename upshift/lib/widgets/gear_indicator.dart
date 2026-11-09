import 'package:flutter/material.dart';

import '../core/themes/AppTheme.dart';
import '../widgets/indicator.dart';

// Maps the raw gear value from the transmission to a label
String gearLabel(int gear) {
  switch (gear) {
    case 0:
      return 'N';
    case 1:
      return '1';
    case 2:
      return '2';
    case 3:
      return '3';
    case 4:
      return '4';
    case 5:
      return '5';
    case 6:
      return '6';
    case 0xFF:
      return 'R';
  }
  return '--';
}

// Gear ladder: R N 1-6 at half opacity with the current gear in solid white.
// R = 0xFF and N = 0. No reading (or unknown value) means nothing is lit.
// All eight letters always on screen
class GearLadder extends StatelessWidget {
  final Stream<int> stream;
  final bool active;
  final int? forceGear;
  final Color cyanStatusColor;
  final Color mintStatusColor;

  const GearLadder({
    super.key,
    required this.stream,
    this.active = true,
    this.forceGear,
    required this.cyanStatusColor,
    required this.mintStatusColor,
  });

  // Label the raw value the transmission reports
  static const gears = <(String, int)>[
    ('R', 0xFF),
    ('N', 0),
    ('1', 1),
    ('2', 2),
    ('3', 3),
    ('4', 4),
    ('5', 5),
    ('6', 6),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (_, snap) {
        final gear = snap.data;

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.widgetBackground,
                border: Border.all(color: AppTheme.widgetBorder, width: 1.2),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [BoxShadow(color: cyanStatusColor, blurRadius: 12)],
              ),
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      Container(width: 4, height: 16, color: cyanStatusColor),
                      const SizedBox(width: 9),
                      Text(
                        'GEAR INDICATOR',
                        style: TextStyle(
                          color: cyanStatusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: mintStatusColor),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'LIVE',
                          style: TextStyle(
                            color: mintStatusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final g in gears)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              g.$1,
                              style: AppTheme.gearStyle.copyWith(
                                color: g.$2 == gear
                                    ? ShiftPalette.white
                                    : AppTheme.appDim,
                                shadows: g.$2 == gear
                                    ? [
                                        Shadow(
                                          color: cyanStatusColor,
                                          blurRadius: 10,
                                        ),
                                        Shadow(
                                          color: cyanStatusColor,
                                          blurRadius: 24,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      // Type of widget
                      const Icon(
                        Icons.sensors,
                        size: 12,
                        color: AppTheme.appDim,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'VEHICLE TELEMETRY',
                        style: TextStyle(
                          color: AppTheme.appDim,
                          fontSize: 9,
                          letterSpacing: 1.3,
                          fontFamily: 'monospace',
                        ),
                      ),

                      const Spacer(),

                      // Cool dev name
                      const Text(
                        'UPSHIFT SYSTEMS',
                        style: TextStyle(
                          color: AppTheme.widgetBorder,
                          fontSize: 9,
                          letterSpacing: 1.2,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
