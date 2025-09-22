import 'package:flutter/material.dart';
import 'package:obd_log/data/models/obd_log.dart';

class LogContainer extends StatelessWidget {
  final List<ObdLogModel> logs;
  const LogContainer({required this.logs, super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final l = logs[index];
        return ListTile(
          leading: Icon(l.direction == "sent" ? Icons.upload : Icons.download),
          title: Text(l.message),
          subtitle: Text(l.timestamp.toIso8601String()),
        );
      },
    );
  }
}
