// DeviceStatus: the devices/{moduleId}/status node (the ESP32 heartbeat).

import 'firebase_value_helpers.dart';

class DeviceStatus {
  /// How old a heartbeat can be before the module counts as offline.
  /// The ESP32 sends one every 10 seconds, so 30 seconds allows for 2 missed beats.
  static const Duration offlineAfter = Duration(seconds: 30);

  /// Server time of the last heartbeat, in milliseconds since epoch. Null if never seen.
  final int? lastSeenMillis;
  final int? wifiSignalDbm;
  final String ipAddress;

  const DeviceStatus({
    required this.lastSeenMillis,
    required this.wifiSignalDbm,
    required this.ipAddress,
  });

  factory DeviceStatus.fromFirebase(Object? rawValue) {
    final statusMap = readMap(rawValue);
    return DeviceStatus(
      lastSeenMillis: readInt(statusMap['lastSeen']),
      wifiSignalDbm: readInt(statusMap['rssi']),
      ipAddress: readString(statusMap['ip']),
    );
  }

  DateTime? get lastSeen {
    if (lastSeenMillis == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(lastSeenMillis!);
  }

  /// True when the last heartbeat is recent enough.
  /// [serverNowMillis] should be the estimated Firebase server time
  /// (phone time + .info/serverTimeOffset), so a wrong phone clock does not matter.
  bool isOnline(int serverNowMillis) {
    if (lastSeenMillis == null) {
      return false;
    }
    final heartbeatAgeMillis = serverNowMillis - lastSeenMillis!;
    return heartbeatAgeMillis <= offlineAfter.inMilliseconds;
  }
}
