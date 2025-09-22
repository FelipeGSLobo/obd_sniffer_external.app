import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as fbs;
import '../models/obd_device.dart';

class ObdProvider {
  final fbs.FlutterBluetoothSerial _classic =
      fbs.FlutterBluetoothSerial.instance;

  /// Scan dispositivos Bluetooth Classic
  Future<List<ObdDevice>> scanClassic(
      {Duration timeout = const Duration(seconds: 6)}) async {
    final devices = <ObdDevice>[];
    try {
      await _classic.requestEnable();
      final stream = _classic.startDiscovery();
      await for (var r in stream) {
        devices.add(ObdDevice(
          id: r.device.address,
          name: r.device.name ?? 'Unknown',
          protocol: ProtocolType.classic,
        ));
      }
    } catch (e) {
      print('Erro no scan Classic: $e');
    }
    // Remove duplicados
    final map = <String, ObdDevice>{};
    for (var d in devices) map[d.id] = d;
    return map.values.toList();
  }

  /// Scan dispositivos BLE
  Future<List<ObdDevice>> scanBle(
      {Duration timeout = const Duration(seconds: 5)}) async {
    final devices = <ObdDevice>[];
    try {
      await FlutterBluePlus.startScan(timeout: timeout);
      await Future.delayed(timeout); // espera scan
      final results = await FlutterBluePlus.scanResults.first;
      for (var r in results) {
        devices.add(ObdDevice(
          id: r.device.id.id,
          name: r.device.name.isEmpty ? r.device.id.id : r.device.name,
          protocol: ProtocolType.ble,
        ));
      }
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print('Erro no scan BLE: $e');
    }
    return devices;
  }

  /// Conecta a um dispositivo BLE ou Classic
  Future<ObdConnection> connect(ObdDevice device,
      {Duration timeout = const Duration(seconds: 10)}) async {
    if (device.protocol == ProtocolType.classic) {
      // Conexão Classic
      final conn =
          await fbs.BluetoothConnection.toAddress(device.id).timeout(timeout);
      final controller = StreamController<String>();
      final buffer = <int>[];

      conn.input?.listen((Uint8List data) {
        buffer.addAll(data);
        for (int i = 0; i < buffer.length; i++) {
          if (buffer[i] == 10 || buffer[i] == 13) {
            final bytes = buffer.sublist(0, i);
            final text = utf8.decode(bytes, allowMalformed: true).trim();
            if (text.isNotEmpty) controller.add(text);
            buffer.removeRange(0, i + 1);
            i = -1;
          }
        }
      },
          onDone: () => controller.close(),
          onError: (e) => controller.addError(e));

      return ObdConnection._classic(conn, controller);
    } else {
      // Conexão BLE
      final bleDevice = (await FlutterBluePlus.scanResults.first)
          .map((r) => r.device)
          .firstWhere((d) => d.id.id == device.id,
              orElse: () => throw Exception('Dispositivo não encontrado'));

      await bleDevice.connect(
        timeout: timeout,
        license: License.free,
      );

      final services = await bleDevice.discoverServices();
      BluetoothCharacteristic? writeChar;

      for (var s in services) {
        for (var c in s.characteristics) {
          if (c.properties.write || c.properties.writeWithoutResponse)
            writeChar ??= c;
        }
      }

      if (writeChar == null) {
        throw Exception(
            'No writable characteristic found for BLE device ${device.name}');
      }

      // Cria controller para leitura de notificações
      final controller =
          ObdConnection.createControllerFromCharacteristic(writeChar);

      return ObdConnection._ble(bleDevice, writeChar, controller);
    }
  }
}

class ObdConnection {
  final fbs.BluetoothConnection? _classicConn;
  final BluetoothDevice? _bleDevice;
  final BluetoothCharacteristic? _writeChar;
  final StreamController<String> _controller;

  // Construtor Classic
  ObdConnection._classic(this._classicConn, this._controller)
      : _bleDevice = null,
        _writeChar = null;

  // Construtor BLE
  ObdConnection._ble(this._bleDevice, this._writeChar, this._controller)
      : _classicConn = null;

  Stream<String> get incoming => _controller.stream;

  Future<void> send(String cmd) async {
    if (_classicConn != null) {
      final toSend = utf8.encode(cmd + '\r');
      _classicConn.output.add(Uint8List.fromList(toSend));
      await _classicConn.output.allSent;
    } else if (_writeChar != null) {
      await _writeChar.write(utf8.encode(cmd + '\r'));
    } else {
      throw Exception('Not connected');
    }
  }

  Future<void> disconnect() async {
    try {
      await _classicConn?.finish();
    } catch (_) {}
    try {
      await _bleDevice?.disconnect();
    } catch (_) {}
    try {
      await _controller.close();
    } catch (_) {}
  }

  // Cria StreamController de leitura de BLE
  static StreamController<String> createControllerFromCharacteristic(
      BluetoothCharacteristic char) {
    final controller = StreamController<String>();
    final buffer = <int>[];

    char.value.listen((bytes) {
      buffer.addAll(bytes);
      for (int i = 0; i < buffer.length; i++) {
        if (buffer[i] == 10 || buffer[i] == 13) {
          final bytesLine = buffer.sublist(0, i);
          final text = utf8.decode(bytesLine, allowMalformed: true).trim();
          if (text.isNotEmpty) controller.add(text);
          buffer.removeRange(0, i + 1);
          i = -1;
        }
      }
    },
        onError: (e) => controller.addError(e),
        onDone: () => controller.close());

    return controller;
  }
}
