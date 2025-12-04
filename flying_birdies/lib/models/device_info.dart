/// Device information for BLE connection persistence
class DeviceInfo {
  final String id;
  final String name;
  final DateTime lastConnected;

  const DeviceInfo({
    required this.id,
    required this.name,
    required this.lastConnected,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lastConnected': lastConnected.millisecondsSinceEpoch,
    };
  }

  /// Create from JSON storage
  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      lastConnected: DateTime.fromMillisecondsSinceEpoch(
        json['lastConnected'] as int,
      ),
    );
  }

  @override
  String toString() =>
      'DeviceInfo(id: $id, name: $name, lastConnected: $lastConnected)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceInfo &&
        other.id == id &&
        other.name == name &&
        other.lastConnected == lastConnected;
  }

  @override
  int get hashCode => Object.hash(id, name, lastConnected);
}
