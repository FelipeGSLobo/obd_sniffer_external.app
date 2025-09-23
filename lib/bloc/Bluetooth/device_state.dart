// ADDED: Enum para um controle claro e explícito do status da conexão.
import 'package:obd_log/data/models/obd_device.dart';

enum ConnectionStatus { disconnected, connecting, connected, failed }

// ADDED: Classe de estado unificada para o ObdDeviceCubit.
// Isso evita o uso de múltiplos `BlocBuilder` ou `setState` na UI para gerenciar
// diferentes aspectos do estado (lista de dispositivos, status, dispositivo conectado).
class ObdDeviceState {
  final List<ObdDevice> devices;
  final ObdDevice? connectedDevice;
  final ConnectionStatus status;
  final String? errorMessage;

  const ObdDeviceState({
    this.devices = const [],
    this.connectedDevice,
    this.status = ConnectionStatus.disconnected,
    this.errorMessage,
  });

  // Método 'copyWith' para facilitar a criação de novos estados a partir do anterior
  // sem modificar o estado original, mantendo a imutabilidade.
  ObdDeviceState copyWith({
    List<ObdDevice>? devices,
    ObdDevice? connectedDevice,
    ConnectionStatus? status,
    String? errorMessage,
    bool clearConnectedDevice = false,
  }) {
    return ObdDeviceState(
      devices: devices ?? this.devices,
      connectedDevice:
          clearConnectedDevice ? null : connectedDevice ?? this.connectedDevice,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
