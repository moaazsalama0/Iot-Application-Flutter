// DeviceAlert: one alerts/{alertId} entry (a critical event from a module).

import 'firebase_value_helpers.dart';

enum AlertSeverity { critical, warning, info }

class DeviceAlert {
  final String alertId;
  final String moduleId;

  /// e.g. 'gas', 'flame', 'highTemperature', 'intrusion'.
  final String type;
  final AlertSeverity severity;
  final String message;

  /// Server time the alert was created, in milliseconds since epoch.
  final int timestampMillis;
  final bool acknowledged;

  const DeviceAlert({
    required this.alertId,
    required this.moduleId,
    required this.type,
    required this.severity,
    required this.message,
    required this.timestampMillis,
    required this.acknowledged,
  });

  factory DeviceAlert.fromFirebase(String alertId, Object? rawValue) {
    final alertMap = readMap(rawValue);
    return DeviceAlert(
      alertId: alertId,
      moduleId: readString(alertMap['moduleId']),
      type: readString(alertMap['type']),
      severity: _parseSeverity(readString(alertMap['severity'])),
      message: readString(alertMap['message']),
      timestampMillis: readInt(alertMap['timestamp']) ?? 0,
      acknowledged: readBool(alertMap['acknowledged']),
    );
  }

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(timestampMillis);

  static AlertSeverity _parseSeverity(String severityText) {
    switch (severityText) {
      case 'critical':
        return AlertSeverity.critical;
      case 'warning':
        return AlertSeverity.warning;
      default:
        return AlertSeverity.info;
    }
  }
}
