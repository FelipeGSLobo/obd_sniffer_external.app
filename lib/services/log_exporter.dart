import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/models/obd_log.dart';

class LogExporter {
  static Future<void> export(List<ObdLogModel> logs) async {
    if (logs.isEmpty) {
      throw Exception('Nenhum log para exportar.');
    }

    // Formata o conteúdo do log
    final buffer = StringBuffer();
    buffer.writeln('--- OBD Log Export ---');
    buffer.writeln(
        'Exportado em: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    buffer.writeln('----------------------');
    for (final log in logs) {
      final direction = log.sent ? '>> SENT' : '<< RECEIVED';
      final timestamp = DateFormat('HH:mm:ss.SSS').format(log.timestamp);
      buffer.writeln('[$timestamp] $direction: ${log.frame}');
    }

    // Cria o arquivo
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${directory.path}/obd_logs_$timestamp.txt';
    final file = File(path);
    await file.writeAsString(buffer.toString());

    // Compartilha o arquivo
    await Share.shareXFiles([XFile(path)], text: 'Logs da Sessão OBD');
  }
}
