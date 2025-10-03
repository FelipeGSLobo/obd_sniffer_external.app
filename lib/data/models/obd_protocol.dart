class ObdProtocol {
  final String name;
  final String code;
  String rpm = "";

  ObdProtocol({required this.name, required this.code, String? rpm}) {
    if (rpm != null) this.rpm = rpm;
  }
}
