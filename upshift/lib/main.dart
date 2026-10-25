import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'reader.dart';
import 'indicator.dart';

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  static const config = ShiftConfig();
  final reader = ObdRpmReader();

  String statusText = 'Not connected';
  bool connecting = false;
  bool connected = false;

  String gearLabel(int gear) {
    switch(gear){
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
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 340,
                  height: 240,
                  child: StreamBuilder<double>(
                    stream: reader.rpmStream,
                    initialData: 0,
                    builder: (_, snap) =>
                        SsBadge(rpm: snap.data ?? 0, config: config),
                  ),
                ),
              ),
            ),
            StreamBuilder<double>(
              stream: reader.rpmStream,
              initialData: 0,
              builder: (_, snap) => Text(
                '${(snap.data ?? 0).round()} RPM',
                style:
                const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
            ),
            StreamBuilder<double>(
              stream: reader.transTempStream,
              builder: (_, snap) => Text(
                snap.hasData ? 'Trans ${snap.data!.round()}°F' : 'Trans --°F',
                style: const TextStyle(fontSize: 20, color: Color(0xFF8A93A0)),
              )
            ),
            StreamBuilder<int>(
              stream: reader.gearStream,
              builder: (_, snap) => Text(
                snap.hasData ? 'Gear ${gearLabel(snap.data!)}' : 'Gear --',
                style: const TextStyle(fontSize: 20, color: Color(0xFF8A93A0)),
              )
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(statusText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF8A93A0))),
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
                  child: Text(connecting
                      ? 'Connecting…'
                      : connected
                      ? 'Disconnect'
                      : 'Connect to adapter'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}