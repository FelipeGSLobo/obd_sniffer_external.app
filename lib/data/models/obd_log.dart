class ObdLogModel {
  final DateTime timestamp;
  final bool sent;
  final String frame;

  ObdLogModel({
    required this.timestamp,
    required this.sent,
    required this.frame,
  });

  factory ObdLogModel.sent(String frame) {
    return ObdLogModel(
      timestamp: DateTime.now(),
      sent: true,
      frame: frame,
    );
  }

  factory ObdLogModel.received(String frame) {
    return ObdLogModel(
      timestamp: DateTime.now(),
      sent: false,
      frame: frame,
    );
  }

  String get direction => sent ? "sent" : "received";
  String get message => frame;
}
