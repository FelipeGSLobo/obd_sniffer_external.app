enum ProtocolType { classic, ble }

class ObdDevice {
  final String id; // address for classic, id for BLE
  final String name;
  final ProtocolType protocol;

  ObdDevice({required this.id, required this.name, required this.protocol});

  @override
  String toString() => '$name (${protocol == ProtocolType.classic ? "Classic" : "BLE"}) - $id';
}
