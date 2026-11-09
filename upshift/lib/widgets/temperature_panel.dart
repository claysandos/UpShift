import 'package:flutter/material.dart';

import '../core/themes/AppTheme.dart';

class TemperaturePanel extends StatelessWidget {
  final Stream<double?> coolantTempStream;
  final Stream<double?> transmissionTempStream;
  final Stream<double?> oilTempStream;
  final Stream<String> connectionStatusStream;
  final String unit;

  // Thresholds configurable for different vehicles
  final double coolantWarning;
  final double coolantCritical;
  final double transmissionWarning;
  final double transmissionCritical;
  final double oilWarning;
  final double oilCritical;

  const TemperaturePanel({
    super.key,
    required this.coolantTempStream,
    required this.transmissionTempStream,
    required this.oilTempStream,
    required this.connectionStatusStream,
    this.unit = '°F',
    this.coolantWarning = 220,
    this.coolantCritical = 240,
    this.transmissionWarning = 220,
    this.transmissionCritical = 240,
    this.oilWarning = 220,
    this.oilCritical = 240,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: connectionStatusStream,
      initialData: 'Disconnected',
      builder: (context, connectionSnapshot) {
        final bool connected = connectionSnapshot.data == 'Connected';

        return StreamBuilder<double?>(
          stream: coolantTempStream,
          builder: (context, coolantSnapshot) {
            return StreamBuilder<double?>(
              stream: transmissionTempStream,
              builder: (context, transmissionSnapshot) {
                return StreamBuilder<double?>(
                  stream: oilTempStream,
                  builder: (context, oilSnapshot) {
                    return _buildPanel(
                      coolantTemp: coolantSnapshot.data,
                      transmissionTemp: transmissionSnapshot.data,
                      oilTemp: oilSnapshot.data,
                      connected: connected,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPanel({
    double? coolantTemp,
    double? transmissionTemp,
    double? oilTemp,
    required bool connected,
  }) {
    Color cyanStatusColor = connected
        ? AppTheme.widgetCyanAccent
        : AppTheme.widgetCyanAccent.withValues(alpha: 0.3);
    Color mintStatusColor = connected
        ? AppTheme.widgetMintAccent
        : AppTheme.widgetMintAccent.withValues(alpha: 0.3);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.widgetBackground,
        border: Border.all(color: AppTheme.widgetBorder, width: 1.2),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: cyanStatusColor, blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(width: 4, height: 16, color: cyanStatusColor),
              const SizedBox(width: 9),
              Text(
                'FLUID TEMPERATURES',
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
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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

          // Temperature readouts
          Row(
            children: [
              Expanded(
                child: _TemperatureReadout(
                  label: 'COOLANT',
                  value: coolantTemp,
                  unit: unit,
                  warningAt: coolantWarning,
                  criticalAt: coolantCritical,
                  scaleMax: 280,
                ),
              ),
              _divider(),
              Expanded(
                child: _TemperatureReadout(
                  label: 'ENGINE',
                  value: oilTemp,
                  unit: unit,
                  warningAt: oilWarning,
                  criticalAt: oilCritical,
                  scaleMax: 320,
                ),
              ),
              _divider(),
              Expanded(
                child: _TemperatureReadout(
                  label: 'TRANSMISSION',
                  value: transmissionTemp,
                  unit: unit,
                  warningAt: transmissionWarning,
                  criticalAt: transmissionCritical,
                  scaleMax: 300,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Footer
          Row(
            children: [
              // Type of widget
              const Icon(Icons.sensors, size: 12, color: AppTheme.appDim),
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
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 75,
      margin: const EdgeInsets.symmetric(horizontal: 9),
      color: AppTheme.widgetBorder,
    );
  }
}

class _TemperatureReadout extends StatelessWidget {
  final String label;
  final double? value;
  final String unit;
  final double warningAt;
  final double criticalAt;
  final double scaleMax;

  const _TemperatureReadout({
    required this.label,
    required this.value,
    required this.unit,
    required this.warningAt,
    required this.criticalAt,
    required this.scaleMax,
  });

  @override
  Widget build(BuildContext context) {
    final bool available = value != null && value!.isFinite;

    final Color statusColor = !available
        ? AppTheme.appDim
        : value! >= criticalAt
        ? AppTheme.red
        : value! >= warningAt
        ? AppTheme.amber
        : AppTheme.widgetMintAccent;

    final String status = !available
        ? 'NO DATA'
        : value! >= criticalAt
        ? 'CRITICAL'
        : value! >= warningAt
        ? 'WARM'
        : 'NORMAL';

    final double progress = available
        ? (value! / scaleMax).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.widgetLabel,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontFamily: 'monospace',
          ),
        ),

        const SizedBox(height: 9),

        // Digital temperature
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                available ? value!.round().toString() : '--',
                style: TextStyle(
                  color: available
                      ? AppTheme.widgetCyanAccent
                      : AppTheme.appDim,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1.5,
                  fontFamily: 'monospace',
                  shadows: available
                      ? [
                          Shadow(
                            color: AppTheme.widgetCyanAccent.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 2),
                child: Text(
                  unit,
                  style: const TextStyle(
                    color: AppTheme.widgetLabel,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Temperature bar
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: AppTheme.appDim,
            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
          ),
        ),

        const SizedBox(height: 7),

        Text(
          status,
          style: TextStyle(
            color: statusColor,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
