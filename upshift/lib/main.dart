import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'reader.dart';
import 'indicator.dart';
import 'color_menu.dart';
import 'shift_menu.dart';

void main() => runApp(const UpshiftApp());

class UpshiftApp extends StatelessWidget {
  const UpshiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

// Maps the raw gear value from the transmission to a label
String gearLabel(int gear) {
  switch (gear) {
    case 0: return 'N';
    case 1: return '1';
    case 2: return '2';
    case 3: return '3';
    case 4: return '4';
    case 5: return '5';
    case 6: return '6';
    case 0xFF: return 'R';
  }
  return '--';
}

// Maps the raw temperature value from the transmission to a color
Color transTempColor(double temp) {
  if (temp < 140) return ShiftPalette.white;
  if (temp <= 200) return ShiftPalette.green;
  if (temp <= 210) return ShiftPalette.amber;
  return ShiftPalette.red;
}

// Gear ladder: 1-6 at half opacity with the current gear in solid white.
// N, R and unknown values show as text under the row. No reading = nothing lit.
class GearLadder extends StatelessWidget {
  final Stream<int> stream;
  const GearLadder({super.key, required this.stream});

  static const dim = Color(0x80F2F4F7);
  static const digitStyle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    fontStyle: FontStyle.italic,
    height: 1,
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (_, snap) {
        final gear = snap.data;
        final inRange = gear != null && gear >= 1 && gear <= 6;
        final extra = (gear == null || inRange) ? '' : gearLabel(gear);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var g = 1; g <= 6; g++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '$g',
                      style: digitStyle.copyWith(
                        color: g == gear ? ShiftPalette.white : dim,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(
              height: 24,
              child: Text(
                extra,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  color: ShiftPalette.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  // The shift points; changed from the shift menu
  ShiftConfig config = const ShiftConfig();
  final reader = ObdRpmReader();

  // The shift palette; changed from the color menu
  ShiftColors colors = const ShiftColors();

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
  }

  @override
  void dispose() {
    reader.dispose();
    super.dispose();
  }

  Future<bool> ensurePermissions() async {
    if (Platform.isAndroid) {
      final r = await [Permission.bluetoothScan, Permission.bluetoothConnect]
          .request();
      return r.values.every((s) => s.isGranted);
    }
    return (await Permission.bluetooth.request()).isGranted;
  }

  Future<void> _connect() async {
    setState(() => connecting = true);
    try {
      if (!await ensurePermissions()) {
        setState(() => statusText = 'Bluetooth permission denied');
        return;
      }
      await reader.connect();
    } catch (e) {
      setState(() => statusText = 'Error: $e');
    } finally {
      if (mounted) setState(() => connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D10),
      body: SafeArea(
        child: Column(
          children: [
            // Menus: Shift configuration and shift colors
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: 'Shift configuration',
                  onPressed: () => showShiftMenu(
                    context,
                    config: config,
                    onChanged: (c) => setState(() => config = c),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.palette_outlined),
                  tooltip: 'Shift colors',
                  onPressed: () => showColorMenu(
                    context,
                    colors: colors,
                    onChanged: (c) => setState(() => colors = c),
                  ),
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
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    GearLadder(stream: reader.gearStream),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                StreamBuilder<double>(
                  stream: reader.rpmStream,
                  initialData: 0,
                  builder: (_, snap) => Text(
                    '${(snap.data ?? 0).round()} RPM',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 24),
                StreamBuilder<double>(
                  stream: reader.transTempStream,
                  builder: (_, snap) => Text(
                    snap.hasData ? 'Trans ${snap.data!.round()}°F' : 'Trans --°F',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: snap.hasData
                          ? transTempColor(snap.data!)
                          : const Color(0xFF8A93A0),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                    onPressed: connecting
                        ? null
                        : connected
                        ? reader.disconnect
                        : _connect,
                    style: FilledButton.styleFrom(backgroundColor: ShiftPalette.white),
                    child: Text(connecting
                        ? 'Connecting…'
                        : connected
                        ? 'Disconnect'
                        : 'Connect to adapter')
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}