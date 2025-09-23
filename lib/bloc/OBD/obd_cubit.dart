import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/obd_log.dart';

class ObdLogCubit extends Cubit<List<ObdLogModel>> {
  ObdLogCubit() : super([]);

  void addLog(ObdLogModel log) {
    emit([...state, log]);
  }

  void clear() => emit([]);
}
