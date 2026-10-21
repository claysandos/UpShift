import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// BLE-only RPM reader for ELM327-style adapters (e.g. Veepeak OBDCheck BLE+)
//
// Flow: scan by name -> connect -> find notify/write characteristics ->
// init ELM327 -> poll PID 010C (RPM) in a loop
class ObdRpmReader {
  // Upper-case substrings that identify adapter's BLE name
  final List<String> nameHints;
  ObdRpmReader({this.nameHints = const ['VEEPEAK', 'OBDCHECK']});

  BluetoothDevice? _device;
  BluetoothCharacteristic? _write;
  BluetoothCharacteristic? _notify;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  final StringBuffer _buf = StringBuffer();
  Completer<String>? _pending;
  bool _running = false;

  final _rpmController = StreamController<double>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  Stream<double> get rpmStream => _rpmController.stream;
  Stream<String> get status => _statusController.stream;
  bool get isConnected => _running;

  void _status(String s) => _statusController.add(s);

  // --- Connect ---

  Future<void> connect({Duration scanTimeout = const Duration(seconds: 12)}) async {
    if (!await FlutterBluePlus.isSupported) {
      throw Exception('Bluetooth LE is not supported on this device');
    }
    _status('Waiting for Bluetooth…');
    await FlutterBluePlus.adapterState
        .where((s) => s == BluetoothAdapterState.on)
        .first
        .timeout(const Duration(seconds: 10));

    _status('Scanning for adapter…');
    final device = await _scanForAdapter(scanTimeout);

    _status('Connecting…');
    await device.connect(timeout: const Duration(seconds: 15));
    _device = device;

    _connSub = device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected) {
        _running = false;
        _status('Disconnected');
      }
    });

    if (Platform.isAndroid) await device.requestMtu(247);

    await _setupGatt(device);
    await _initElm();

    _running = true;
    _status('Connected');
    unawaited(_pollLoop());
  }

  Future<BluetoothDevice> _scanForAdapter(Duration timeout) async {
    final found = Completer<BluetoothDevice>();
    final sub = FlutterBluePlus.onScanResults.listen((results) {
      for (final r in results) {
        final name = (r.advertisementData.advName.isNotEmpty
            ? r.advertisementData.advName
            : r.device.platformName)
            .toUpperCase();
        if (name.isNotEmpty &&
            nameHints.any(name.contains) &&
            !found.isCompleted) {
          found.complete(r.device);
        }
      }
    });
    try {
      await FlutterBluePlus.startScan(timeout: timeout);
      return await found.future.timeout(timeout);
    } on TimeoutException {
      throw Exception('Adapter not found. Plugged in with ignition on?');
    } finally {
      await FlutterBluePlus.stopScan();
      await sub.cancel();
    }
  }

  // Prefers the FFF0 service; otherwise uses the first service that has both
  // a notify and a write characteristic. Logs every characteristic found
  Future<void> _setupGatt(BluetoothDevice device) async {
    final services = await device.discoverServices();

    for (final s in services) {
      for (final c in s.characteristics) {
        final p = c.properties;
        _status('GATT ${s.uuid.str128} / ${c.uuid.str128} '
            'notify=${p.notify} write=${p.write} noResp=${p.writeWithoutResponse}');
      }
    }

    final fff0 = services
        .where((s) => s.uuid.str128.toLowerCase().contains('fff0'))
        .toList();

    for (final s in fff0.isNotEmpty ? fff0 : services) {
      for (final c in s.characteristics) {
        final p = c.properties;
        if ((p.notify || p.indicate) && _notify == null) _notify = c;
        if ((p.write || p.writeWithoutResponse) && _write == null) _write = c;
      }
      if (_notify != null && _write != null) break;
    }

    if (_notify == null || _write == null) {
      throw Exception('Could not find notify/write characteristics');
    }

    final sub = _notify!.onValueReceived.listen(_onBytes);
    device.cancelWhenDisconnected(sub);
    await _notify!.setNotifyValue(true);
  }

  // ------------------------------------------------------------------- ELM

  void _onBytes(List<int> bytes) {
    _buf.write(String.fromCharCodes(bytes));
    if (_buf.toString().contains('>')) {
      // '>' is the ELM327 prompt that ends every reply
      final reply = _buf.toString();
      _buf.clear();
      _pending?.complete(reply);
      _pending = null;
    }
  }

  Future<String> _send(String cmd,
      {Duration timeout = const Duration(seconds: 2)}) async {
    _buf.clear();
    _pending = Completer<String>();
    final w = _write!;
    await w.write('$cmd\r'.codeUnits,
        withoutResponse: w.properties.writeWithoutResponse);
    return _pending!.future.timeout(timeout);
  }

  Future<void> _initElm() async {
    _status('Initializing adapter…');
    for (final cmd in ['ATZ', 'ATE0', 'ATL0', 'ATS0', 'ATH0', 'ATSP0']) {
      try {
        await _send(cmd, timeout: const Duration(seconds: 3));
      } on TimeoutException {
        _status('No reply to $cmd (continuing)');
      }
    }
  }

  Future<void> _pollLoop() async {
    // First request triggers protocol auto-detection
    var first = true;
    while (_running) {
      try {
        final reply = await _send(
          '010C',
          timeout: first
              ? const Duration(seconds: 10)
              : const Duration(milliseconds: 800),
        );
        first = false;
        final rpm = parseRpm(reply);
        if (rpm != null) _rpmController.add(rpm);
      } on TimeoutException {
        // skip this sample
      } catch (e) {
        _status('Read error: $e');
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  /// "41 0C 1A F8" -> ((0x1A * 256) + 0xF8) / 4 = 1726 rpm
  static double? parseRpm(String reply) {
    final clean = reply.replaceAll(RegExp(r'[\s>]'), '').toUpperCase();
    final i = clean.indexOf('410C');
    if (i < 0 || clean.length < i + 8) return null;
    final a = int.tryParse(clean.substring(i + 4, i + 6), radix: 16);
    final b = int.tryParse(clean.substring(i + 6, i + 8), radix: 16);
    if (a == null || b == null) return null;
    return (a * 256 + b) / 4;
  }

  // ---------------------------------------------------------------- cleanup

  Future<void> disconnect() async {
    _running = false;
    await _connSub?.cancel();
    await _device?.disconnect();
    _device = null;
    _write = null;
    _notify = null;
  }

  void dispose() {
    disconnect();
    _rpmController.close();
    _statusController.close();
  }
}