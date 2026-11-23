// AuthGate: shows the login screen or the dashboard depending on
// whether a user is signed in. Updates automatically on login/logout.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Still checking whether someone is already signed in.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final signedInUser = snapshot.data;
        if (signedInUser == null) {
          return LoginScreen(authService: authService);
        }
        return DashboardScreen(authService: authService);
      },
    );
  }
}
