import 'package:flutter/foundation.dart'; // For kReleaseMode

class SafeError {
  /// Returns a clean message for users in Release mode,
  /// but the full raw error in Debug mode.
  static String format(dynamic e, {String fallback = "Something went wrong. Please try again."}) {
    // 1. DEVELOPER MODE: Return everything
    if (kDebugMode) {
      return "Dev Error: $e";
    }

    // 2. PRODUCTION MODE: Sanitize
    final String raw = e.toString().toLowerCase();

    // Check for common Network/Server leaks
    if (raw.contains('socketexception') ||
        raw.contains('host lookup') ||
        raw.contains('connection refused') ||
        raw.contains('network is unreachable')) {
      return "Network Error: Unable to connect to the server.";
    }

    if (raw.contains('timeout')) {
      return "The connection timed out. Please check your internet.";
    }

    if (raw.contains('handshake') || raw.contains('certificate')) {
      return "Security Error: Could not verify server identity.";
    }

    if (raw.contains('401') || raw.contains('403')) {
      return "Access Denied.";
    }

    // If it's not a known network error, return the generic fallback
    // to avoid leaking stack traces or variable names.
    return fallback;
  }
}