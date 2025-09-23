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
      _connection = await _repository.connect(device);
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
