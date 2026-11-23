// AuthService: all Firebase Authentication logic lives here.
// Screens call these methods and never use FirebaseAuth directly.

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  /// Emits the signed-in user, or null when signed out.
  /// The AuthGate listens to this to switch between login and dashboard.
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// The user who is signed in right now, or null.
  User? get currentUser => _firebaseAuth.currentUser;

  /// Signs in with email and password.
  /// Throws an [AuthFailure] with a readable message when it fails.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_readableMessage(error.code));
    }
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  /// Turns Firebase error codes into messages the user can understand.
  String _readableMessage(String errorCode) {
    switch (errorCode) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Sign-in failed ($errorCode).';
    }
  }
}

/// Error thrown by [AuthService] with a message that is safe to show in the UI.
class AuthFailure implements Exception {
  final String message;

  AuthFailure(this.message);

  @override
  String toString() => message;
}
