import 'package:flutter/material.dart';
import 'package:obd_log/data/models/obd_log.dart';

class ObdLogContainer extends StatelessWidget {
  final List<ObdLogModel> logs;
  final ScrollController? controller;

  const ObdLogContainer({super.key, required this.logs, this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(
            "${log.timestamp.toIso8601String()} - ${log.message}",
            style: const TextStyle(
              fontFamily: "monospace",
              fontSize: 12,
              color: Color(0xFF87CEEB), // azul bebê
            ),
          ),
        );
      },
    );
  }
}
