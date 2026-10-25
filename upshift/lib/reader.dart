import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// BLE-only RPM reader for ELM327-style adapters (e.g. Veepeak OBDCheck BLE+)
//
// Flow: scan by name -> connect -> find notify/write characteristics ->
// init ELM327 -> poll PID 010C (RPM) in a loop -> poll mode 22 PID 1940
class ObdRpmReader {
  // Upper-case substrings that identify adapter's BLE name
  final List<String> nameHints;
  // Full request for the current gear ('22199A' = Mode 22 + PID)
  final String gearPid;
  // Address of the transmission module (GM = 7E2)
  final String tcmHeader;

  ObdRpmReader({
    this.nameHints = const ['VEEPEAK', 'OBDCHECK'],
    this.gearPid = '22199A',
    this.tcmHeader = '7E2'
  });

  BluetoothDevice? _device;
  BluetoothCharacteristic? _write;
  BluetoothCharacteristic? _notify;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  final StringBuffer _buf = StringBuffer();
  Completer<String>? _pending;
  bool _running = false;

  final _rpmController = StreamController<double>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  final _transTempController = StreamController<double>.broadcast();
  int transTempReadFails = 0;
  final _gearController = StreamController<int>.broadcast();
  int transGearReadFails = 0;

  Stream<String> get status => _statusController.stream;

  // Engine RPM in revolutions per minute
  Stream<double> get rpmStream => _rpmController.stream;
  // Transmission fluid temperature in degrees F
  Stream<double> get transTempStream => _transTempController.stream;
  // Current transmission gear
  Stream<int> get gearStream => _gearController.stream;

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
    unawaited(pollLoop());
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

  /// Loop to continuously poll for RPM and transmission temperature
  Future<void> pollLoop() async {
    // First request triggers protocol auto-detection
    var first = true;
    var rpmReads = 0;
    while (_running) {
      try {
        final rpmReply = await _send(
          '010C',
          timeout: first
              ? const Duration(seconds: 10)
              : const Duration(milliseconds: 800),
        );
        first = false;
        final rpm = parseRpm(rpmReply);
        if (rpm != null) _rpmController.add(rpm);

        // Every ~20 RPM reads, get transmission temp. Gives up after 3 failures -> unsupported car doesn't slow down RPMs
        rpmReads++;
        if (transTempReadFails < 3 && rpmReads % 20 == 0) {
          await pollTransTemp();
        }
      } on TimeoutException {
        // skip this sample
      } catch (e) {
        _status('Read error: $e');
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  /// Poll for the transmission temperature in Celsius, convert it to Fahrenheit, add it to the stream
  Future<void> pollTransTemp() async {
    try {
      // Read GM transmission fluid temp (Mode 22 PID 1940)
      await _send('ATSH7E2', timeout: const Duration(seconds: 1));
      final reply = await _send('221940', timeout: const Duration(seconds: 2));
      final celsiusTemp = parseTransTemp(reply);
      if (celsiusTemp != null) {
        // Convert celsiusTemp to Fahrenheit then add to stream
        _transTempController.add(celsiusTemp * 9 / 5 + 32);
        transTempReadFails = 0;
      } else {
        // Report failure
        transTempReadFails++;
        if (transTempReadFails >= 3) _status('Trans temp not supported, process stopped.');
      }
    } on TimeoutException {
      // Report failure
      transTempReadFails++;
    } finally {
      try {
        // Back to normal broadcast address for RPM requests
        await _send('ATSH7DF', timeout: const Duration(seconds: 1));
      } on TimeoutException {
        // ignore
      }
    }
  }

  /// Poll for the current gear, add it to the stream
  Future<void> pollGear() async {
    try {
      // Read GM current gear (Mode 22 PID 199A)
      await _send('ATSH7E2', timeout: const Duration(seconds: 1));
      final reply = await _send('22199A', timeout: const Duration(seconds: 2));
      final gear = parseGear(reply, gearPid);
      if (gear != null){
        _gearController.add(gear);
        transGearReadFails = 0;
      } else {
        // Report failure
        transGearReadFails++;
        if (transGearReadFails >= 3) _status('Trans gear not supported, process stopped.');
      }
    } on TimeoutException {
      // Report failure
      transGearReadFails++;
    } finally {
      try {
        // Back to normal broadcast address for RPM requests
        await _send('ATSH7DF', timeout: const Duration(seconds: 1));
      } on TimeoutException {
        // ignore
      }
    }
  }

  /// "62 19 9A 03" -> 0x03 = 3rd gear
  static int? parseGear(String reply, String request) {
    final clean = reply.replaceAll(RegExp(r'[\s>]'), '').toUpperCase();
    final prefix = '62${request.substring(2).toUpperCase()}';
    final index = clean.indexOf(prefix);
    if (index < 0 || clean.length < index + prefix.length + 2) return null;
    return int.tryParse(
      clean.substring(index + prefix.length, index + prefix.length + 2),
      radix: 16);
  }

  /// "62 19 40 7B" -> 0x7B (123) - 40 = 83 degrees Celsius
  static double? parseTransTemp(String reply) {
    final clean = reply.replaceAll(RegExp(r'[\s>]'), '').toUpperCase();
    final index = clean.indexOf('621940');
    if (index < 0 || clean.length < index + 8) return null;
    final answer = int.tryParse(clean.substring(index + 6, index + 8), radix: 16);
    return answer == null ? null : (answer - 40).toDouble();
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