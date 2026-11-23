// DashboardScreen: placeholder shown after login.
// The live module cards will be added here once DeviceService exists.

import 'package:material_ui/material_ui.dart';

import '../services/auth_service.dart';

class DashboardScreen extends StatelessWidget {
  final AuthService authService;

  const DashboardScreen({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    final userEmail = authService.currentUser?.email ?? 'unknown user';

    return Scaffold(
      appBar: AppBar(
        title: const Text('IoSphere'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: authService.signOut,
          ),
        ],
      ),
      body: Center(
        child: Text('Signed in as $userEmail'),
      ),
    );
  }
}
