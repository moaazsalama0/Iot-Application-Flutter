// Entry point: starts Firebase, then shows the login or dashboard screen.

import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';

Future<void> main() async {
  // Flutter must be ready before Firebase can start.
  WidgetsFlutterBinding.ensureInitialized();

  // Connect to the IoSphere Firebase project (settings come from flutterfire configure).
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const IoSphereApp());
}

class IoSphereApp extends StatelessWidget {
  const IoSphereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoSphere',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const AuthGate(),
    );
  }
}
