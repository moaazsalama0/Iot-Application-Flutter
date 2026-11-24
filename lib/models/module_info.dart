// ModuleInfo: the devices/{moduleId}/info node (written by the ESP32 on boot).

import 'firebase_value_helpers.dart';

class ModuleInfo {
  final String name;
  final String owner;
  final String type;
  final String firmware;

  const ModuleInfo({
    required this.name,
    required this.owner,
    required this.type,
    required this.firmware,
  });

  /// Builds the info from the raw Firebase node.
  /// [moduleId] is used as the display name if the ESP32 has not sent one yet.
  factory ModuleInfo.fromFirebase(Object? rawValue, {required String moduleId}) {
    final infoMap = readMap(rawValue);
    return ModuleInfo(
      name: readString(infoMap['name'], fallback: moduleId),
      owner: readString(infoMap['owner']),
      type: readString(infoMap['type'], fallback: 'generic'),
      firmware: readString(infoMap['firmware']),
    );
  }
}
