import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/obd_device.dart';
import '../../data/models/obd_log.dart';
import '../../data/providers/obd_provider.dart'; // Importa a classe ObdConnection
import '../../data/repositories/obd_repository.dart';
import '../OBD/obd_cubit.dart';
import 'device_state.dart'; // **IMPORTANTE: Crie este arquivo, que foi fornecido na resposta anterior**

// O Cubit agora gerencia um ObdDeviceState completo, não apenas uma lista.
class ObdDeviceCubit extends Cubit<ObdDeviceState> {
  final ObdRepository _repository = ObdRepository();
  StreamSubscription<String>? _rxSub;
  // A conexão agora é fortemente tipada para evitar erros.
  ObdConnection? _connection;
  ProtocolType _currentProtocol = ProtocolType.classic;

  ObdDeviceCubit() : super(const ObdDeviceState());

  ProtocolType get currentProtocol => _currentProtocol;

  void setProtocol(ProtocolType p) {
    _currentProtocol = p;
    // Reseta o estado ao trocar de protocolo
    emit(state.copyWith(
        devices: [],
        status: ConnectionStatus.disconnected,
        clearConnectedDevice: true));
  }

  Future<void> scan() async {
    // Emite um estado de 'conectando' para que a UI possa mostrar um indicador de progresso.
    emit(state.copyWith(status: ConnectionStatus.connecting, devices: []));
    try {
      final devices = await _repository.scanDevices(protocol: _currentProtocol);
      emit(state.copyWith(
          devices: devices, status: ConnectionStatus.disconnected));
    } catch (e) {
      emit(state.copyWith(
        status: ConnectionStatus.failed,
        errorMessage: 'Erro ao escanear: $e',
      ));
    }
  }

  Future<void> connect(ObdDevice device, ObdLogCubit logCubit) async {
    await disconnect();
    // Emite um estado de 'conectando' para a UI.
    emit(state.copyWith(status: ConnectionStatus.connecting));
    try {
      _connection = await _repository.connect(device, logCubit);
      _rxSub = _connection?.incoming.listen(
        (frame) {
          // Usa o construtor de fábrica para manter a consistência.
          logCubit.addLog(ObdLogModel.received(frame));
        },
        onError: (e) {
          logCubit.addLog(ObdLogModel.received('ERROR: $e'));
          disconnect();
        },
        onDone: () {
          logCubit.addLog(ObdLogModel.received('DISCONNECTED'));
          disconnect();
        },
      );

      // Atualiza o estado para 'conectado' e armazena o dispositivo.
      emit(state.copyWith(
        status: ConnectionStatus.connected,
        connectedDevice: device,
      ));
    } catch (e) {
      // Em caso de erro, emite um estado de 'falha' com a mensagem.
      print(e);
      logCubit.addLog(ObdLogModel.received('ERROR: $e'));
      emit(state.copyWith(
        status: ConnectionStatus.failed,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> sendCommand(String cmd, ObdLogCubit logCubit) async {
    try {
      if (_connection == null || state.status != ConnectionStatus.connected) {
        // Evita enviar comandos se não estiver conectado.
        logCubit.addLog(ObdLogModel.received('ERRO: Não conectado.'));
        return;
      }
      await _connection!.send(cmd);
      // Usa o construtor de fábrica para consistência.
      logCubit.addLog(ObdLogModel.sent(cmd));
    } catch (e) {
      logCubit.addLog(ObdLogModel.received('ERRO ao enviar: $e'));
      emit(state.copyWith(
        status: state.status,
        errorMessage: e.toString(),
      ));
    }
  }

  StreamSubscription<String> listen(
      void Function(String) onData, ObdLogCubit logCubit) {
    StreamSubscription<String> sub = _connection!.listenResponses((resp) {
      onData(resp);
      logCubit.addLog(ObdLogModel.received(resp));
    });
    return sub;
  }

  Future<List<String>> checkObdProtocol(ObdLogCubit logCubit) async {
    final List<String> protocols = [
      'ATSP0', // auto
      'ATSP1', // SAE J1850 PWM	41.6 kbaud
      'ATSP2', // SAE J1850 VPW	10.4 kbaud
      'ATSP3', // ISO9141-2
      'ATSP4', // KWP slow init
      'ATSP5', // KWP fast init
      'ATSP6', // CAN 11bit 500kbps
      'ATSP7', // CAN 29bit 500kbps
      'ATSP8', // CAN 11bit 250kbps
      'ATSP9', // CAN 29bit 250kbps
      'ATSPA', // J1939 CAN
      'ATSPB', // USER1 CAN
      'ATSPC', // USER2 CAN
    ];

    await sendCommand('ATZ', logCubit);
    await Future.delayed(const Duration(seconds: 1));
    await sendCommand('ATE0', logCubit); // echo off
    await Future.delayed(const Duration(milliseconds: 500));
    await sendCommand('ATL0', logCubit); // linefeeds off
    await Future.delayed(const Duration(milliseconds: 500));
    await sendCommand('ATS0', logCubit); // spaces off
    await Future.delayed(const Duration(milliseconds: 500));
    await sendCommand('ATH0', logCubit); // headers off
    await Future.delayed(const Duration(milliseconds: 500));

    List<String> res = [];
    for (String p in protocols) {
      await _connection!.send(p);
      await Future.delayed(const Duration(milliseconds: 300));

      logCubit.addLog(ObdLogModel.sent("Testing $p"));
      // Confirma se está respondendo
      final StreamSubscription<String> subscription = listen((resp) {
        logCubit.addLog(ObdLogModel.received("Return $p: $resp"));
        print("Lendo retorno: $resp");
        if ((resp.contains('41 00') || resp.contains('F004')) &&
            !res.contains(p)) {
          //Resposta válida
          res.add(p);
        }
      }, logCubit);
      if (['ATSPA', 'ATSPB', 'ATSPC'].contains(p)) {
        await _connection!.send('0300F004');
      } else {
        await _connection!.send('0100');
      }
      await Future.delayed(const Duration(milliseconds: 1500));
      subscription.cancel();
    }
    if (res.isEmpty) res.add("Nenhum protocolo compatível encontrado!");
    return res;
  }

  Future<void> disconnect() async {
    await _rxSub?.cancel();
    await _connection?.disconnect();
    _rxSub = null;
    _connection = null;
    // Reseta o estado para 'desconectado'.
    emit(state.copyWith(
      status: ConnectionStatus.disconnected,
      clearConnectedDevice: true,
    ));
  }

  Future<void> clearDevices() async {
    emit(state.copyWith(devices: []));
  }
}
