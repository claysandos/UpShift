import 'dart:async';

import 'package:flutter/material.dart';

import '../core/themes/AppTheme.dart';
import '../core/obd/reader.dart';

class ConnectionMenuButton extends StatefulWidget {
  final ObdReader reader;

  const ConnectionMenuButton({super.key, required this.reader});

  @override
  State<ConnectionMenuButton> createState() => _ConnectionMenuButtonState();
}

class _ConnectionMenuButtonState extends State<ConnectionMenuButton> {
  StreamSubscription<String>? _statusSub;
  String _status = 'Disconnected';
  bool _busy = false;

  bool get isConnected => _status == 'Connected';

  bool get isConnecting =>
      _status == 'Waiting for Bluetooth…' ||
      _status == 'Scanning for adapter…' ||
      _status == 'Connecting…' ||
      _status == 'Initializing adapter…';

  @override
  void initState() {
    super.initState();

    _statusSub = widget.reader.status.listen((status) {
      if (!mounted) return;

      setState(() {
        _status = status;
      });
    });
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() => _busy = true);

    try {
      await widget.reader.connect();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _status = 'Disconnected';
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Connection failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _disconnect() async {
    setState(() => _busy = true);

    try {
      await widget.reader.disconnect();

      if (!mounted) return;

      setState(() {
        _status = 'Disconnected';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _toggleConnection() async {
    if (_busy || isConnecting) return;

    if (isConnected) {
      await _disconnect();
    } else {
      await _connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor = isConnected
        ? AppTheme.widgetCyanAccent
        : isConnecting
        ? AppTheme.amber
        : AppTheme.appDim;

    return IconButton(
      onPressed: (_busy || isConnecting) ? null : _toggleConnection,
      tooltip: isConnected ? 'Disconnect adapter' : 'Connect to adapter',
      style: AppTheme.buttonStyle.copyWith(
        foregroundColor: WidgetStatePropertyAll(statusColor),
        side: WidgetStatePropertyAll(
          BorderSide(
            color: isConnected
                ? AppTheme.widgetMintAccent
                : AppTheme.widgetBorder,
            width: 1.2,
          ),
        ),
      ),
      icon: _busy || isConnecting
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                color: statusColor,
              ),
            )
          : Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
              size: 18,
            ),
    );
  }
}
