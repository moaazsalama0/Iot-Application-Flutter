// DeviceModule: one student's hardware module, i.e. one devices/{moduleId} node.
// The sensor/actuator/command/setting keys differ per module, so they are kept
// as maps; each module's screen reads the keys it knows (see docs/data_contract.md).

import 'device_status.dart';
import 'firebase_value_helpers.dart';
import 'module_info.dart';

class DeviceModule {
  final String moduleId;
  final ModuleInfo info;

  /// Latest sensor readings, e.g. {'temperature': 27.4, 'motion': false}.
  final Map<String, dynamic> sensors;

  /// Actual actuator states reported by the ESP32, e.g. {'fan': 'ON'}.
  final Map<String, dynamic> actuators;

  /// Desired states requested by the app, e.g. {'fan': 'ON'}.
  final Map<String, dynamic> commands;

  /// Automation settings, e.g. {'autoMode': true, 'tempThreshold': 35}.
  final Map<String, dynamic> settings;

  final DeviceStatus status;

  const DeviceModule({
    required this.moduleId,
    required this.info,
    required this.sensors,
    required this.actuators,
    required this.commands,
    required this.settings,
    required this.status,
  });

  factory DeviceModule.fromFirebase(String moduleId, Object? rawValue) {
    final moduleMap = readMap(rawValue);
    return DeviceModule(
      moduleId: moduleId,
      info: ModuleInfo.fromFirebase(moduleMap['info'], moduleId: moduleId),
      sensors: readMap(moduleMap['sensors']),
      actuators: readMap(moduleMap['actuators']),
      commands: readMap(moduleMap['commands']),
      settings: readMap(moduleMap['settings']),
      status: DeviceStatus.fromFirebase(moduleMap['status']),
    );
  }

  /// Reads a numeric sensor, e.g. sensorNumber('temperature'). Null if missing.
  double? sensorNumber(String sensorName) {
    final value = sensors[sensorName];
    if (value is num) {
      return value.toDouble();
    }
    return null;
  }

  /// Reads a true/false sensor, e.g. sensorFlag('motion'). False if missing.
  bool sensorFlag(String sensorName) {
    return readBool(sensors[sensorName]);
  }

  /// True when the ESP32 has not yet applied the latest command for [actuatorName].
  bool isCommandPending(String actuatorName) {
    if (!commands.containsKey(actuatorName)) {
      return false;
    }
    return commands[actuatorName] != actuators[actuatorName];
  }
}
