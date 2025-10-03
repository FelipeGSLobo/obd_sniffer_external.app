import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as fbs;
import 'package:obd_log/bloc/Bluetooth/device_cubit.dart';
import 'package:obd_log/bloc/OBD/obd_cubit.dart';
import 'package:obd_log/data/models/obd_log.dart';
import '../models/obd_device.dart';

class ObdProvider {
  // ... (código de scan permanece o mesmo) ...
  final fbs.FlutterBluetoothSerial _classic =
      fbs.FlutterBluetoothSerial.instance;

  Future<List<ObdDevice>> scanClassic(
      {Duration timeout = const Duration(seconds: 6)}) async {
    final map = <String, ObdDevice>{};

    try {
      await _classic.requestEnable();
      final sub =
          _classic.startDiscovery().listen((fbs.BluetoothDiscoveryResult r) {
        final d = r.device;
        // Ignora dispositivos sem nome, que geralmente não são o que o usuário procura.
        if (d.name != null && d.name!.isNotEmpty) {
          final id = d.address;
          final name = d.name ?? 'Unknown';
          map[id] =
              ObdDevice(id: id, name: name, protocol: ProtocolType.classic);
        }
      });

      await Future.delayed(timeout);
      await sub.cancel();
    } catch (e) {
      print(e.toString()); // Em um app real, use um logger.
      rethrow; // Propaga o erro para a camada superior (Cubit) tratar.
    }

    return map.values.toList();
  }

  Future<List<ObdDevice>> scanBle(
      {Duration timeout = const Duration(seconds: 5)}) async {
    final map = <String, ObdDevice>{};
    StreamSubscription<List<ScanResult>>? sub;

    try {
      if (!FlutterBluePlus.isScanningNow) {
        sub = FlutterBluePlus.scanResults.listen((results) {
          for (final r in results) {
            final dev = r.device;
            if (dev.platformName.isNotEmpty) {
              final id = dev.remoteId.str;
              final name = dev.platformName;
              map[id] =
                  ObdDevice(id: id, name: name, protocol: ProtocolType.ble);
            }
          }
        });

        FlutterBluePlus.startScan(timeout: timeout);
        await Future.delayed(timeout);
      }
    } catch (e) {
      print(e.toString());
      rethrow;
    } finally {
      await sub?.cancel();
    }

    return map.values.toList();
  }

  Future<ObdConnection> connect(ObdDevice device, ObdLogCubit logCubit,
      {Duration timeout = const Duration(seconds: 10)}) async {
    if (device.protocol == ProtocolType.classic) {
      final conn = await fbs.BluetoothConnection.toAddress(device.id);
      final controller = StreamController<String>();

      // REFACTORED: Lógica de buffer aprimorada para lidar com o prompt '>'.
      List<int> buffer = [];
      conn.input?.listen((Uint8List data) {
        buffer.addAll(data);
        // O caractere '>' (62) geralmente indica o fim de uma resposta do ELM327.
        // O caractere de nova linha '\r' (13) também é um delimitador comum.
        while (buffer.contains(13) || buffer.contains(62)) {
          int endOfLineIndex = buffer.indexOf(13);
          int promptIndex = buffer.indexOf(62);

          int splitIndex = -1;
          if (endOfLineIndex != -1 && promptIndex != -1) {
            splitIndex =
                (endOfLineIndex < promptIndex) ? endOfLineIndex : promptIndex;
          } else if (endOfLineIndex != -1) {
            splitIndex = endOfLineIndex;
          } else {
            splitIndex = promptIndex;
          }

          final frameBytes = buffer.sublist(0, splitIndex);
          final text = utf8.decode(frameBytes, allowMalformed: true).trim();
          if (text.isNotEmpty) {
            controller.add(text);
            logCubit.addLog(ObdLogModel.received(text));
          }
          buffer.removeRange(0, splitIndex + 1);
        }
      },
          onDone: () => controller.close(),
          onError: (e) => controller.addError(e));

      return ObdConnection._classic(conn, controller);
    } else {
      // A lógica BLE permanece a mesma, mas com o mesmo aprimoramento de buffer.
      final bleDevice = BluetoothDevice.fromId(device.id);

      await bleDevice.connect(timeout: timeout, license: License.free);

      final services = await bleDevice.discoverServices();
      BluetoothCharacteristic? writeChar;
      BluetoothCharacteristic? notifyChar;
      BluetoothCharacteristic? indicateChar;

      // ... (lógica para encontrar características permanece a mesma) ...
      for (var s in services) {
        for (var c in s.characteristics) {
          logCubit.addLog(ObdLogModel.received(
              'Característica BLE encontrada: ${c.characteristicUuid}, propriedades: ${c.properties}'));
          if (c.properties.write || c.properties.writeWithoutResponse)
            writeChar ??= c;
          if (c.properties.notify) notifyChar ??= c;
          if (c.properties.indicate) indicateChar ??= c;
        }
      }
      logCubit.addLog(ObdLogModel.received(
          'Serviços descobertos: ${services.length}, WriteChar: ${writeChar?.characteristicUuid}, NotifyChar: ${notifyChar?.characteristicUuid}'));
      notifyChar ??= indicateChar;
      notifyChar ??= writeChar;

      if (notifyChar == null) {
        await bleDevice.disconnect();
        throw Exception(
            'Característica de notificação/escrita não encontrada para ${device.name}');
      }

      await notifyChar.setNotifyValue(true);

      List<int> buffer = [];
      final controller = StreamController<String>.broadcast();
      notifyChar.lastValueStream.listen((data) {
        buffer.addAll(data);
        while (buffer.contains(13) || buffer.contains(62)) {
          int endOfLineIndex = buffer.indexOf(13);
          int promptIndex = buffer.indexOf(62);

          int splitIndex = -1;
          if (endOfLineIndex != -1 && promptIndex != -1) {
            splitIndex =
                (endOfLineIndex < promptIndex) ? endOfLineIndex : promptIndex;
          } else if (endOfLineIndex != -1) {
            splitIndex = endOfLineIndex;
          } else {
            splitIndex = promptIndex;
          }

          final frameBytes = buffer.sublist(0, splitIndex);
          final text = utf8.decode(frameBytes, allowMalformed: true).trim();
          if (text.isNotEmpty) {
            print("Received BLE: $text");
            logCubit.addLog(ObdLogModel.received(text));
            controller.add(text);
          }
          buffer.removeRange(0, splitIndex + 1);
        }
      },
          onError: (e) => controller.addError(e),
          onDone: () => controller.close());

      return ObdConnection._ble(bleDevice, writeChar, controller);
    }
  }
}

/// Simple connection wrapper used by repository/cubit
class ObdConnection {
  final fbs.BluetoothConnection? _classicConn;
  final BluetoothDevice? _bleDevice;
  final BluetoothCharacteristic? _writeChar;
  final StreamController<String> _controller;

  ObdConnection._classic(this._classicConn, this._controller)
      : _bleDevice = null,
        _writeChar = null;

  ObdConnection._ble(this._bleDevice, this._writeChar, this._controller)
      : _classicConn = null;

  Stream<String> get incoming => _controller.stream;

  Future<void> send(String cmd) async {
    final commandWithCr = '$cmd\r';
    final bytesToSend = utf8.encode(commandWithCr);

    if (_classicConn != null && _classicConn.isConnected) {
      _classicConn.output.add(bytesToSend);
      await _classicConn.output.allSent;
    } else if (_bleDevice != null &&
        _bleDevice.isConnected &&
        _writeChar != null) {
      await _writeChar.write(bytesToSend);
    } else {
      throw Exception('Não conectado');
    }
  }

  Future<void> disconnect() async {
    try {
      await _classicConn?.close();
    } catch (_) {}
    try {
      await _bleDevice?.disconnect();
    } catch (_) {}
    try {
      await _controller.close();
    } catch (_) {}
  }
}

extension ObdConnectionExt on ObdConnection {
  /// Escuta continuamente as respostas e executa o callback [onData].
  /// Retorna o StreamSubscription para permitir cancelamento.
  StreamSubscription<String> listenResponses(void Function(String) onData) {
    return incoming.listen(
      (resp) => onData(resp),
      onError: (err) => print("Erro OBD: $err"),
      onDone: () => print("Conexão OBD encerrada"),
    );
  }
}
