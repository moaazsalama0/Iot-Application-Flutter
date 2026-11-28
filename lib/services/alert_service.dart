// AlertService: live alerts from all modules, and acknowledging them.
// ESP32s create alerts in alerts/; the app only reads them and
// sets `acknowledged` to true (the security rules allow nothing else).
// Write methods throw a ServiceException with a message for the user.

import 'package:firebase_database/firebase_database.dart';

import '../models/device_alert.dart';
import '../models/firebase_value_helpers.dart';
import 'service_exception.dart';

class AlertService {
  /// How many of the newest alerts are downloaded. Older ones stay in the database.
  static const int recentAlertLimit = 50;

  final FirebaseDatabase _database;

  AlertService({FirebaseDatabase? database})
      : _database = database ?? FirebaseDatabase.instance;

  DatabaseReference get _alertsRef => _database.ref('alerts');

  // ---------------------------------------------------------------------------
  // Reading (live streams for StreamBuilder)
  // ---------------------------------------------------------------------------

  /// The newest alerts (acknowledged or not), newest first.
  Stream<List<DeviceAlert>> watchRecentAlerts() {
    final newestAlertsQuery = _alertsRef.orderByChild('timestamp').limitToLast(recentAlertLimit);

    return newestAlertsQuery.onValue.map((event) {
      final recentAlerts = <DeviceAlert>[];
      final rawAlerts = readMap(event.snapshot.value);
      rawAlerts.forEach((alertId, rawAlert) {
        recentAlerts.add(DeviceAlert.fromFirebase(alertId, rawAlert));
      });
      recentAlerts.sort((first, second) => second.timestampMillis.compareTo(first.timestampMillis));
      return recentAlerts;
    });
  }

  /// Alerts the user has not acknowledged yet, newest first.
  Stream<List<DeviceAlert>> watchActiveAlerts() {
    return watchRecentAlerts().map((recentAlerts) {
      final activeAlerts = <DeviceAlert>[];
      for (final alert in recentAlerts) {
        if (!alert.acknowledged) {
          activeAlerts.add(alert);
        }
      }
      return activeAlerts;
    });
  }

  /// Active alerts of one module, e.g. for that module's own screen.
  Stream<List<DeviceAlert>> watchActiveAlertsForModule(String moduleId) {
    return watchActiveAlerts().map((activeAlerts) {
      final moduleAlerts = <DeviceAlert>[];
      for (final alert in activeAlerts) {
        if (alert.moduleId == moduleId) {
          moduleAlerts.add(alert);
        }
      }
      return moduleAlerts;
    });
  }

  /// Number of active alerts, e.g. for a badge on the dashboard.
  Stream<int> watchActiveAlertCount() {
    return watchActiveAlerts().map((activeAlerts) => activeAlerts.length);
  }

  // ---------------------------------------------------------------------------
  // Writing
  // ---------------------------------------------------------------------------

  /// Marks one alert as seen by the user.
  Future<void> acknowledge(String alertId) {
    final acknowledgedRef = _alertsRef.child(alertId).child('acknowledged');
    return runFirebaseWrite(acknowledgedRef.set(true));
  }

  /// Marks several alerts as seen, in a single write.
  Future<void> acknowledgeAll(List<DeviceAlert> alertsToAcknowledge) {
    if (alertsToAcknowledge.isEmpty) {
      return Future.value();
    }

    final acknowledgedPaths = <String, Object?>{};
    for (final alert in alertsToAcknowledge) {
      acknowledgedPaths['alerts/${alert.alertId}/acknowledged'] = true;
    }
    return runFirebaseWrite(_database.ref().update(acknowledgedPaths));
  }
}
