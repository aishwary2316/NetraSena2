import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../pages/auth.dart';

class SessionGuard extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const SessionGuard({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard> with WidgetsBindingObserver {
  final ApiService _api = ApiService();
  Timer? _timer;
  DateTime? _lastInteraction;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastInteraction = DateTime.now();

    // Check session every 1 minute
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _checkSession());

    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final storedActive = await _api.getLastActiveTimestamp();
    if (storedActive != null && mounted) {
      setState(() {
        _lastInteraction = storedActive;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Track App Lifecycle (Background/Foreground)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _api.updateLastActivity();
    } else if (state == AppLifecycleState.resumed) {
      _restoreSession().then((_) => _checkSession());
    }
  }

  void _onUserInteraction() {
    _lastInteraction = DateTime.now();
  }

  Future<void> _checkSession() async {
    // 1. Check if user is logged in
    final token = await _api.getToken();
    if (token == null) return;

    final loginTime = await _api.getLoginTimestamp();
    if (loginTime == null) return;

    final now = DateTime.now();
    final lastActive = _lastInteraction ?? now;

    // 2. Day vs Night Logic (06:00 to 18:00 is Day)
    // Rule: "During changes... day time should be considered"
    // Meaning: If NOW is day OR Last Active was Day, use Day limits.
    final bool isDayNow = now.hour >= 6 && now.hour < 18;
    final bool wasDayActive = lastActive.hour >= 6 && lastActive.hour < 18;
    final bool useDayRules = isDayNow || wasDayActive;

    // 3. Define Limits
    // Day: 30m inactive, 3h absolute
    // Night: 15m inactive, 45m absolute
    final int inactivityLimitMins = useDayRules ? 30 : 15;
    final int absoluteLimitMins = useDayRules ? 180 : 45;

    final int inactiveDuration = now.difference(lastActive).inMinutes;
    final int sessionDuration = now.difference(loginTime).inMinutes;

    String? logoutReason;

    if (inactiveDuration >= inactivityLimitMins) {
      logoutReason = 'Session expired due to inactivity ($inactiveDuration mins).';
    } else if (sessionDuration >= absoluteLimitMins) {
      logoutReason = 'Maximum login duration reached ($absoluteLimitMins mins).';
    }

    if (logoutReason != null) {
      _performLogout(logoutReason);
    }
  }

  Future<void> _performLogout(String reason) async {
    _timer?.cancel();
    await _api.localLogout();
    debugPrint("Auto-Logout: $reason");

    if (widget.navigatorKey.currentState != null) {
      // FORCE Logout: Remove all routes and push AuthPage with reason
      widget.navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (ctx) => AuthPage(sessionExpiredMessage: reason),
        ),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listener captures taps globally before they reach nested widgets
    return Listener(
      onPointerDown: (_) => _onUserInteraction(),
      onPointerMove: (_) => _onUserInteraction(),
      onPointerHover: (_) => _onUserInteraction(),
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}