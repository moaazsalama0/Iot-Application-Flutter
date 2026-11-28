// Shared error handling for every database write made by the services.

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

/// How long to wait for the server to confirm a write before telling the user.
const Duration firebaseWriteTimeout = Duration(seconds: 8);

/// Error thrown by the services with a message that is safe to show in the UI.
class ServiceException implements Exception {
  final String message;

  ServiceException(this.message);

  @override
  String toString() => message;
}

/// Waits for a Firebase write and turns failures into a [ServiceException].
Future<void> runFirebaseWrite(Future<void> pendingWrite) async {
  try {
    await pendingWrite.timeout(firebaseWriteTimeout);
  } on TimeoutException {
    // Firebase keeps the write queued and sends it once the connection returns.
    throw ServiceException(
      'No connection to the server. The change will be sent when you are back online.',
    );
  } on FirebaseException catch (error) {
    if (error.code == 'permission-denied') {
      throw ServiceException('You are not allowed to change this value.');
    }
    throw ServiceException('Could not send the change (${error.code}).');
  }
}
