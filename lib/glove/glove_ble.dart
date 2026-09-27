import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'glove_session.dart';

/// The only file that talks to Bluetooth: finds the glove, connects, and hands every
/// notification to [GloveSession]. Name and UUIDs: see "BLE protocol" in CLAUDE.md.
class GloveBle {
  GloveBle(this.session);

  final GloveSession session;

  static const deviceName = 'SignSuara-Glove';
  static final serviceUuid = Guid('6b5384d0-483c-4d29-b3e7-4c404e3defce');
  static final rowUuid = Guid('2fce7dc7-6ea7-4d15-8e66-280c660ecb8b');
  static const minMtu = 100; // a row is up to ~85 bytes + 3 bytes of BLE overhead
  static const _scanTime = Duration(seconds: 10);

  BluetoothDevice? _device;
  StreamSubscription<BluetoothConnectionState>? _stateSub;

  Future<void> connect() async {
    await _stateSub?.cancel();
    try {
      session.setStatus('Checking Bluetooth...', link: GloveLink.busy);
      final adapter = await FlutterBluePlus.adapterState
          .firstWhere((s) => s != BluetoothAdapterState.unknown)
          .timeout(_scanTime);
      if (adapter != BluetoothAdapterState.on) {
        return session.setStatus(
            'Bluetooth is ${adapter.name}. Turn it on / allow "Nearby devices", then try again.',
            link: GloveLink.disconnected);
      }

      session.setStatus('Searching for $deviceName...', link: GloveLink.busy);
      await FlutterBluePlus.startScan(withNames: [deviceName], timeout: _scanTime);
      final ScanResult result;
      try {
        result = await FlutterBluePlus.onScanResults.expand((list) => list).first.timeout(_scanTime);
      } on TimeoutException {
        return session.setStatus('Glove not found. Is it switched on?', link: GloveLink.disconnected);
      } finally {
        await FlutterBluePlus.stopScan();
      }

      session.setStatus('Connecting...', link: GloveLink.busy);
      final device = _device = result.device;
      // On Android, connect() also asks for MTU 512; the glove accepts up to 185.
      await device.connect(license: License.nonprofit, timeout: const Duration(seconds: 15));
      if (device.mtuNow < minMtu) {
        await device.disconnect();
        return session.setStatus('MTU too small (${device.mtuNow}): rows would be cut off.',
            link: GloveLink.disconnected);
      }

      final services = await device.discoverServices();
      final rowChar = services
          .firstWhere((s) => s.uuid == serviceUuid,
              orElse: () => throw StateError('Glove service not found. Old firmware?'))
          .characteristics
          .firstWhere((c) => c.uuid == rowUuid);

      session.startStream();
      device.cancelWhenDisconnected(rowChar.onValueReceived.listen(session.addPacket));
      await rowChar.setNotifyValue(true);

      session.setStatus('Connected (MTU ${device.mtuNow})', link: GloveLink.connected);
      _stateSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          session.setStatus('Disconnected', link: GloveLink.disconnected);
        }
      });
    } catch (e) {
      session.setStatus('Error: $e', link: GloveLink.disconnected);
      await _device?.disconnect().catchError((_) {});
    }
  }

  Future<void> disconnect() async => _device?.disconnect();
}
