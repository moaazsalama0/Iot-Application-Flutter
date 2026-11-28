// DashboardScreen: temporary backend test screen shown after login.
// It shows every module's live data and online state so the services can be
// checked before the real UI exists. The UI team will replace this screen;
// the way it uses DeviceService / PresenceService is the pattern to copy.

import 'package:material_ui/material_ui.dart';

import '../models/device_alert.dart';
import '../models/device_module.dart';
import '../models/module_keys.dart';
import '../services/alert_service.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';
import '../services/presence_service.dart';
import '../services/service_exception.dart';

class DashboardScreen extends StatefulWidget {
  final AuthService authService;

  const DashboardScreen({super.key, required this.authService});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _deviceService = DeviceService();
  final _presenceService = PresenceService();
  final _alertService = AlertService();

  // Created once, so rebuilding the screen does not restart the Firebase listeners.
  late final Stream<List<DeviceModule>> _modulesStream = _deviceService.watchAllModules();
  late final Stream<Map<String, bool>> _onlineStream = _presenceService.watchOnlineModules();
  late final Stream<bool> _connectionStream = _presenceService.watchConnection();
  late final Stream<List<DeviceAlert>> _activeAlertsStream = _alertService.watchActiveAlerts();

  /// Runs a service write and shows its error message, if any, in a snackbar.
  Future<void> _runAndReportErrors(Future<void> Function() serviceWrite) async {
    try {
      await serviceWrite();
    } on ServiceException catch (failure) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<void> _sendGateCommand(String gateValue) {
    return _runAndReportErrors(
      () => _deviceService.sendCommand(ModuleIds.parking, ParkingKeys.gate, gateValue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IoSphere'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: widget.authService.signOut,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildConnectionBanner(),
          _buildActiveAlerts(),
          Expanded(child: _buildModuleList()),
        ],
      ),
    );
  }

  Widget _buildConnectionBanner() {
    return StreamBuilder<bool>(
      stream: _connectionStream,
      builder: (context, snapshot) {
        final isConnected = snapshot.data ?? true;
        if (isConnected) {
          return const SizedBox.shrink();
        }
        return Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.errorContainer,
          padding: const EdgeInsets.all(8),
          child: const Text('No connection to the server', textAlign: TextAlign.center),
        );
      },
    );
  }

  Widget _buildActiveAlerts() {
    return StreamBuilder<List<DeviceAlert>>(
      stream: _activeAlertsStream,
      builder: (context, snapshot) {
        final activeAlerts = snapshot.data ?? [];
        if (activeAlerts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.errorContainer,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Alerts (${activeAlerts.length})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _runAndReportErrors(
                      () => _alertService.acknowledgeAll(activeAlerts),
                    ),
                    child: const Text('Dismiss all'),
                  ),
                ],
              ),
              for (final alert in activeAlerts) _buildAlertRow(alert),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlertRow(DeviceAlert alert) {
    final isWarning = alert.severity != AlertSeverity.info;
    return Row(
      children: [
        Icon(isWarning ? Icons.warning_amber : Icons.info_outline, size: 18),
        const SizedBox(width: 6),
        Expanded(child: Text('${alert.moduleId}: ${alert.message}')),
        IconButton(
          icon: const Icon(Icons.check, size: 18),
          tooltip: 'Dismiss',
          onPressed: () => _runAndReportErrors(() => _alertService.acknowledge(alert.alertId)),
        ),
      ],
    );
  }

  Widget _buildModuleList() {
    return StreamBuilder<List<DeviceModule>>(
      stream: _modulesStream,
      builder: (context, modulesSnapshot) {
        if (modulesSnapshot.hasError) {
          return Center(child: Text('Could not load modules:\n${modulesSnapshot.error}'));
        }
        if (!modulesSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allModules = modulesSnapshot.data!;
        if (allModules.isEmpty) {
          return const Center(child: Text('No modules have sent data yet.'));
        }

        return StreamBuilder<Map<String, bool>>(
          stream: _onlineStream,
          builder: (context, onlineSnapshot) {
            final onlineByModule = onlineSnapshot.data ?? {};
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final deviceModule in allModules)
                  _buildModuleCard(deviceModule, onlineByModule[deviceModule.moduleId] ?? false),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildModuleCard(DeviceModule deviceModule, bool isOnline) {
    final statusColor = isOnline ? Colors.green : Colors.grey;
    final statusText = isOnline ? 'Online' : 'Offline';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    deviceModule.info.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Icon(Icons.circle, size: 12, color: statusColor),
                const SizedBox(width: 4),
                Text(statusText),
              ],
            ),
            const SizedBox(height: 8),
            Text('Sensors: ${deviceModule.sensors}'),
            Text('Actuators: ${deviceModule.actuators}'),
            Text('Settings: ${deviceModule.settings}'),
            if (deviceModule.moduleId == ModuleIds.parking) _buildGateButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildGateButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          FilledButton(
            onPressed: () => _sendGateCommand(ParkingKeys.open),
            child: const Text('Open gate'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _sendGateCommand(ParkingKeys.closed),
            child: const Text('Close gate'),
          ),
        ],
      ),
    );
  }
}
