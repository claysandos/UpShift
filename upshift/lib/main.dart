import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/obd/reader.dart';
import '../core/themes/AppTheme.dart';
import '../widgets/indicator.dart';
import '../widgets/color_menu.dart';
import '../widgets/connection_menu_button.dart';
import '../widgets/gear_indicator.dart';
import '../widgets/shift_menu.dart';
import '../widgets/temperature_panel.dart';

void main() => runApp(const UpshiftApp());

class UpshiftApp extends StatelessWidget {
  const UpshiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  // The OBD II reader
  final reader = ObdReader();
  Color cyanStatusColor = AppTheme.widgetCyanAccent.withValues(alpha: 0.3);
  Color mintStatusColor = AppTheme.widgetMintAccent.withValues(alpha: 0.3);

  // The shift points; changed from the shift menu
  ShiftConfig config = const ShiftConfig();

  // The shift palette; changed from the color menu
  ShiftColors colors = const ShiftColors();

  // static const Color border = Color(0xFF29434D);

  String statusText = 'Not connected';
  bool connecting = false;
  bool connected = false;

  @override
  void initState() {
    super.initState();
    reader.status.listen((s) {
      if (!mounted) return;
      setState(() {
        statusText = s;
        if (s == 'Connected') connected = true;
        if (s == 'Disconnected') connected = false;
      });
    });
    cyanStatusColor = connected
        ? AppTheme.widgetCyanAccent
        : AppTheme.widgetCyanAccent.withValues(alpha: 0.3);
    mintStatusColor = connected
        ? AppTheme.widgetMintAccent
        : AppTheme.widgetMintAccent.withValues(alpha: 0.3);
  }

  @override
  void dispose() {
    reader.dispose();
    super.dispose();
  }

  Future<bool> ensurePermissions() async {
    if (Platform.isAndroid) {
      final r = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
      return r.values.every((s) => s.isGranted);
    }
    return (await Permission.bluetooth.request()).isGranted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Menus: Connection Menu, Indicator Configuration, and Color Configuration
            Row(
              children: [
                Image.asset(
                  'assets/icon/upshift.png',
                  width: 80,
                  height: 70,
                  fit: BoxFit.cover,
                ),

                Spacer(),

                ConnectionMenuButton(reader: reader),
                IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: 'Indicator Configuration',
                  onPressed: () => showShiftMenu(
                    context,
                    config: config,
                    onChanged: (c) => setState(() => config = c),
                    connectionStatusStream: reader.status,
                  ),
                  style: AppTheme.buttonStyle,
                ),
                IconButton(
                  icon: const Icon(Icons.palette_outlined),
                  tooltip: 'Color Configuration',
                  onPressed: () => showColorMenu(
                    context,
                    colors: colors,
                    onChanged: (c) => setState(() => colors = c),
                    connectionStatusStream: reader.status,
                  ),
                  style: AppTheme.buttonStyle,
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 340,
                      height: 240,
                      child: StreamBuilder<double>(
                        stream: reader.rpmStream,
                        initialData: 0,
                        builder: (_, snap) => SsBadge(
                          rpm: snap.data ?? 0,
                          config: config,
                          colors: colors,
                          isActive: (snap.data ?? 0) > 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  GearLadder(
                    stream: reader.gearStream,
                    cyanStatusColor: cyanStatusColor,
                    mintStatusColor: mintStatusColor,
                  ),
                  const SizedBox(height: 32),
                  TemperaturePanel(
                    coolantTempStream: reader.coolantTempStream,
                    oilTempStream: reader.oilTempStream,
                    transmissionTempStream: reader.transTempStream,
                    connectionStatusStream: reader.status,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
