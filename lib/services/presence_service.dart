// PresenceService: answers "is the phone connected?" and "is each module online?".
// A module is online when its status/lastSeen heartbeat is recent
// (see DeviceStatus.offlineAfter). Times are compared in server time,
// so a wrong clock on the phone does not break the online/offline status.

import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

import '../models/device_status.dart';
import '../models/firebase_value_helpers.dart';

class PresenceService {
  /// How often online/offline is re-checked even when no new data arrives.
  /// Without this, a module that stops sending would never turn "offline".
  static const Duration recheckInterval = Duration(seconds: 5);

  final FirebaseDatabase _database;

  PresenceService({FirebaseDatabase? database})
      : _database = database ?? FirebaseDatabase.instance;

  /// True while the phone is connected to the Firebase server.
  /// Use it to show a "No internet connection" banner.
  Stream<bool> watchConnection() {
    return _database.ref('.info/connected').onValue.map((event) {
      return event.snapshot.value == true;
    });
  }

  /// Online state of every module, e.g. {'parking_module': true, 'lighting_module': false}.
  /// Emits again whenever a heartbeat arrives and every [recheckInterval].
  Stream<Map<String, bool>> watchOnlineModules() {
    late StreamController<Map<String, bool>> controller;
    StreamSubscription<DatabaseEvent>? devicesSubscription;
    StreamSubscription<DatabaseEvent>? offsetSubscription;
    Timer? recheckTimer;

    var latestStatuses = <String, DeviceStatus>{};
    var serverTimeOffsetMillis = 0;

    void emitOnlineState() {
      final phoneNowMillis = DateTime.now().millisecondsSinceEpoch;
      final serverNowMillis = phoneNowMillis + serverTimeOffsetMillis;

      final onlineByModule = <String, bool>{};
      latestStatuses.forEach((moduleId, deviceStatus) {
        onlineByModule[moduleId] = deviceStatus.isOnline(serverNowMillis);
      });
      controller.add(onlineByModule);
    }

    void handleDevicesEvent(DatabaseEvent event) {
      final updatedStatuses = <String, DeviceStatus>{};
      final rawDevices = readMap(event.snapshot.value);
      rawDevices.forEach((moduleId, rawModule) {
        final rawStatus = readMap(rawModule)['status'];
        updatedStatuses[moduleId] = DeviceStatus.fromFirebase(rawStatus);
      });
      latestStatuses = updatedStatuses;
      emitOnlineState();
    }

    void handleOffsetEvent(DatabaseEvent event) {
      serverTimeOffsetMillis = readInt(event.snapshot.value) ?? 0;
      emitOnlineState();
    }

    controller = StreamController<Map<String, bool>>(
      onListen: () {
        offsetSubscription = _database
            .ref('.info/serverTimeOffset')
            .onValue
            .listen(handleOffsetEvent);
        devicesSubscription = _database
            .ref('devices')
            .onValue
            .listen(handleDevicesEvent, onError: controller.addError);
        recheckTimer = Timer.periodic(recheckInterval, (_) => emitOnlineState());
      },
      onCancel: () async {
        recheckTimer?.cancel();
        await devicesSubscription?.cancel();
        await offsetSubscription?.cancel();
      },
    );

    return controller.stream;
  }
}
