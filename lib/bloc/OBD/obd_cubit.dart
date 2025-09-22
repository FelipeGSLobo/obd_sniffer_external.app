import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/obd_log.dart';
import '../../data/models/obd_device.dart';
import '../../data/repositories/obd_repository.dart';

class ObdCubit extends Cubit<List<ObdLogModel>> {
  final ObdRepository _repository = ObdRepository();
  StreamSubscription<String>? _rxSub;
  dynamic _connection;
  ProtocolType _currentProtocol = ProtocolType.classic;
  ObdDevice? connectedDevice;

  ObdCubit() : super([]);

  ProtocolType get currentProtocol => _currentProtocol;
  void setProtocol(ProtocolType p) {
    _currentProtocol = p;
  }

  Future<List<ObdDevice>> scan() async {
    return await _repository.scanDevices(protocol: _currentProtocol);
  }

  Future<void> connect(ObdDevice device) async {
    await disconnect();
    connectedDevice = device;
    _connection = await _repository.connect(device);
    _rxSub = _connection.incoming.listen((frame) {
      final current = List.of(state);
      current.add(ObdLogModel(frame: frame, timestamp: DateTime.now(), sent: false));
      emit(current);
    }, onError: (e) {
      final current = List.of(state);
      current.add(ObdLogModel(frame: 'ERROR: \$e', timestamp: DateTime.now(), sent: false));
      emit(current);
    }, onDone: () {
      final current = List.of(state);
      current.add(ObdLogModel(frame: 'DISCONNECTED', timestamp: DateTime.now(), sent: false));
      emit(current);
    });
  }

  Future<void> sendCommand(String cmd) async {
    if (_connection == null) throw Exception('Not connected');
    await _connection.send(cmd);
    final current = List.of(state);
    current.add(ObdLogModel(frame: cmd, timestamp: DateTime.now(), sent: true));
    emit(current);
  }

  Future<void> disconnect() async {
    try {
      await _rxSub?.cancel();
    } catch (_) {}
    try {
      await _connection?.disconnect();
    } catch (_) {}
    _rxSub = null;
    _connection = null;
    connectedDevice = null;
  }

  Future<void> clear() async {
    emit([]);
  }
}
