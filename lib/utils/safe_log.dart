import 'package:flutter/foundation.dart'; // Import for kReleaseMode

/// This function only prints if the app is in DEBUG mode.
/// In RELEASE mode (Production), it does absolutely nothing.
void devLog(String message) {
  if (kDebugMode) {
    // Only prints when running 'flutter run'
    print(message);
  }
}