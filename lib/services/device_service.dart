// DeviceService: reads live module data and sends commands/settings.
// All Realtime Database access for devices/ goes through this class;
// screens only use its streams and methods (see docs/data_contract.md).
// Write methods throw a ServiceException with a message for the user.

import 'package:firebase_database/firebase_database.dart';

import '../models/device_module.dart';
import 'service_exception.dart';

class DeviceService {
  final FirebaseDatabase _database;

  DeviceService({FirebaseDatabase? database})
      : _database = database ?? FirebaseDatabase.instance;

  DatabaseReference get _devicesRef => _database.ref('devices');

  // ---------------------------------------------------------------------------
  // Reading (live streams for StreamBuilder)
  // ---------------------------------------------------------------------------

  /// All modules, updated live whenever any value changes.
  /// Emits an empty list when no module has written data yet.
  Stream<List<DeviceModule>> watchAllModules() {
    return _devicesRef.onValue.map((event) {
      final allModules = <DeviceModule>[];
      final rawDevices = event.snapshot.value;
      if (rawDevices is Map) {
        rawDevices.forEach((moduleId, rawModule) {
          allModules.add(DeviceModule.fromFirebase(moduleId.toString(), rawModule));
        });
      }
      allModules.sort((first, second) => first.moduleId.compareTo(second.moduleId));
      return allModules;
    });
  }

  /// One module, updated live. Emits null while the module has no data yet.
  Stream<DeviceModule?> watchModule(String moduleId) {
    return _devicesRef.child(moduleId).onValue.map((event) {
      if (!event.snapshot.exists) {
        return null;
      }
      return DeviceModule.fromFirebase(moduleId, event.snapshot.value);
    });
  }

  // ---------------------------------------------------------------------------
  // Writing
  // ---------------------------------------------------------------------------

  /// Asks a module to change an actuator, e.g.
  /// sendCommand(ModuleIds.parking, ParkingKeys.gate, ParkingKeys.open).
  /// The ESP32 reports the real result in the module's `actuators` node.
  Future<void> sendCommand(String moduleId, String commandName, Object value) {
    final commandRef = _devicesRef.child(moduleId).child('commands').child(commandName);
    return runFirebaseWrite(commandRef.set(value));
  }

  /// Changes one automation setting, e.g.
  /// updateSetting(ModuleIds.lighting, LightingKeys.nearThreshold, 25).
  Future<void> updateSetting(String moduleId, String settingName, Object value) {
    final settingRef = _devicesRef.child(moduleId).child('settings').child(settingName);
    return runFirebaseWrite(settingRef.set(value));
  }

  /// Changes several settings of one module in a single write.
  Future<void> updateSettings(String moduleId, Map<String, Object> newSettings) {
    final settingsRef = _devicesRef.child(moduleId).child('settings');
    return runFirebaseWrite(settingsRef.update(newSettings));
  }
}
