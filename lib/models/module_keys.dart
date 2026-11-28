// Names and values from docs/data_contract.md, section 6.
// Use these constants instead of typing strings like 'walkSignal' by hand:
// a typo in a key is silently rejected by the database rules.

/// The moduleId of each hardware module.
class ModuleIds {
  static const String pedestrian = 'pedestrian_module';
  static const String lighting = 'lighting_module';
  static const String parking = 'parking_module';

  static const List<String> all = [pedestrian, lighting, parking];
}

/// Values shared by several modules.
class CommonKeys {
  /// Setting: true = the ESP32 runs its automation, false = manual commands only.
  static const String autoMode = 'autoMode';

  static const String on = 'ON';
  static const String off = 'OFF';
}

/// 6.1 Pedestrian Crossing.
class PedestrianKeys {
  // sensors
  static const String crossRequest = 'crossRequest';
  static const String pedestrianDetected = 'pedestrianDetected';

  // actuator / command, with its values
  static const String walkSignal = 'walkSignal';
  static const String walk = 'WALK';
  static const String stop = 'STOP';

  // actuator only (the ESP32 sets it to match walkSignal; the app never commands it)
  static const String carLight = 'carLight';
  static const String red = 'RED';
  static const String yellow = 'YELLOW';
  static const String green = 'GREEN';

  // settings
  static const String crossingTime = 'crossingTime';
}

/// 6.2 Smart Street Lighting.
class LightingKeys {
  // sensors
  static const String vehicleDistance = 'vehicleDistance';

  // actuator / command (values: CommonKeys.on / CommonKeys.off)
  static const String streetLight = 'streetLight';

  // settings
  static const String nearThreshold = 'nearThreshold';
  static const String lightOffDelay = 'lightOffDelay';
}

/// 6.3 Smart Parking.
class ParkingKeys {
  static const int slotCount = 3;

  // sensors (slot keys are built from the slot number 1..3)
  static String slotDistance(int slotNumber) => 'slot${slotNumber}Distance';
  static String slotOccupied(int slotNumber) => 'slot${slotNumber}Occupied';
  static const String gateDistance = 'gateDistance';
  static const String carAtGate = 'carAtGate';
  static const String freeSlots = 'freeSlots';

  // actuators (slot LEDs and the LCD follow the sensors; the app cannot command them)
  static String slotLed(int slotNumber) => 'slot${slotNumber}Led';
  static const String lcdText = 'lcdText';

  /// The text the entrance LCD shows for a number of free slots.
  static String lcdTextFor(int freeSlotCount) {
    if (freeSlotCount <= 0) {
      return 'FULL';
    }
    if (freeSlotCount == 1) {
      return '1 slot available';
    }
    return '$freeSlotCount slots available';
  }

  // actuator / command, with its values
  static const String gate = 'gate';
  static const String open = 'OPEN';
  static const String closed = 'CLOSED';

  // settings
  static const String occupiedDistance = 'occupiedDistance';
  static const String gateOpenTime = 'gateOpenTime';
}

/// 6.4 Alert types.
class AlertTypes {
  static const String parkingFull = 'parkingFull';
  static const String gateBlocked = 'gateBlocked';
  static const String sensorFailure = 'sensorFailure';
}
