import 'package:obd_log/bloc/OBD/obd_cubit.dart';

import '../providers/obd_provider.dart';
import '../models/obd_device.dart';

class ObdRepository {
  final ObdProvider _provider = ObdProvider();

  Future<List<ObdDevice>> scanDevices({required ProtocolType protocol}) async {
    if (protocol == ProtocolType.classic) {
      return await _provider.scanClassic();
    } else {
      return await _provider.scanBle();
    }
  }

  Future<dynamic> connect(ObdDevice device, ObdLogCubit logCubit) async {
    return await _provider.connect(device, logCubit);
  }
}
