import 'dart:io'; // For Platform check
import 'package:flutter/foundation.dart'; // For kReleaseMode
import 'package:flutter/material.dart';
import 'package:safe_device/safe_device.dart'; // Security Package
import 'pages/auth.dart'; // Your Auth Page
import '../utils/safe_log.dart';
void main() async {
  // 1. Ensure bindings are initialized before async checks
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Default to "Secure" so we can run the app if checks pass (or are skipped)
  bool isDeviceSecure = true;

  // 3. PERFORM SECURITY CHECKS ONLY IN RELEASE MODE
  // This solves your "How do I develop?" problem:
  // - Debug Mode (You): kReleaseMode is false -> Checks SKIPPED.
  // - Release Mode (Police): kReleaseMode is true -> Checks RUN.
  if (kReleaseMode) {
    try {
      // Check A: Is the device Rooted (Android) or Jailbroken (iOS)?
      bool isJailBroken = await SafeDevice.isJailBroken;

      // Check B: Are Developer Options enabled? (Android Only)
      // Note: USB Debugging exists inside Developer Options.
      // If Dev Options are ON, we consider the device insecure for Law Enforcement use.
      bool isDevMode = false;
      if (Platform.isAndroid) {
        isDevMode = await SafeDevice.isDevelopmentModeEnable;
      }

      // If any violation is found, lock the app
      if (isJailBroken || isDevMode) {
        isDeviceSecure = false;
      }
    } catch (e) {
      // In a high-security context, if the security check crashes,
      // you might choose to fail closed (set isDeviceSecure = false).
      // For now, we just print the error.
      devLog("Security check error: $e");
    }
  }

  // 4. Run the App (Normal vs Security Violation Screen)
  runApp(isDeviceSecure ? const MyApp() : const SecurityViolationApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netra Sarthi',
      debugShowCheckedModeBanner: false,
      // Matching your existing theme colors from auth.dart
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthPage(),
    );
  }
}

// --- THE BLOCKING SCREEN ---
class SecurityViolationApp extends StatelessWidget {
  const SecurityViolationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFB71C1C), // Dark Red
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.gpp_bad_rounded, size: 100, color: Colors.white),
                SizedBox(height: 24),
                Text(
                  "ACCESS DENIED",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  "Security Violation Detected",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 30),
                Text(
                  "This device violates the security protocols required for the Netra Sarthi Surveillance System.\n\n"
                      "• Root/Jailbreak detected\n"
                      "• Developer Options enabled",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}