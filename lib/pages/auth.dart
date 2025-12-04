// lib/pages/auth.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../utils/safe_log.dart';
import '../services/api_service.dart';
import '../utils/validators.dart';
import 'home_page.dart';

class AuthPage extends StatefulWidget {
  final String? sessionExpiredMessage;

  // This constructor allows main.dart to pass the expiry message
  const AuthPage({super.key, this.sessionExpiredMessage});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  @override
  Widget build(BuildContext context) {
    // FIX: Removed nested MaterialApp.
    // We return LoginPage directly so it stays within the root MaterialApp context.
    return LoginPage(sessionExpiredMessage: widget.sessionExpiredMessage);
  }
}

class LoginPage extends StatefulWidget {
  final String? sessionExpiredMessage;

  const LoginPage({super.key, this.sessionExpiredMessage});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final ApiService api = ApiService();
  final LocalAuthentication auth = LocalAuthentication();

  // CONTROL FLAG: Change this to 'true' to re-enable Biometrics later
  final bool _isBiometricEnabled = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // FIX: Show Session Expired Message if it exists
    if (widget.sessionExpiredMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.sessionExpiredMessage!,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'DISMISS',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      });
    }
  }

  Future<void> _signIn() async {
    // 1. INPUT VALIDATION
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    // 2. BIOMETRIC INTERLOCK
    bool isBiometricAuthenticated = false;

    if (_isBiometricEnabled) {
      try {
        final bool canCheckBiometrics = await auth.canCheckBiometrics;

        if (canCheckBiometrics) {
          isBiometricAuthenticated = await auth.authenticate(
            localizedReason: 'Officer identity verification required',
            options: const AuthenticationOptions(
              biometricOnly: true,
              stickyAuth: true,
            ),
          );
        } else {
          // Fallback if hardware not available
          isBiometricAuthenticated = false;
        }
      } catch (e) {
        devLog('Biometric Error: $e');
        setState(() {
          _error = 'Biometric verification error';
          _loading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Biometric Error: $e')),
          );
        }
        return;
      }
    } else {
      // BYPASS MODE
      devLog('Biometrics disabled in code. Bypassing...');
      isBiometricAuthenticated = true;
    }

    if (!isBiometricAuthenticated) {
      setState(() {
        _error = 'Biometric authentication failed';
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric authentication failed')),
        );
      }
      return;
    }

    // 3. NETWORK LOGIN
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Helper to safely parse booleans from JSON
    bool parseBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v.toString().trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }

    try {
      devLog('auth.dart -> attempting login for: $email');
      final result = await api.login(email, password);
      devLog('auth.dart -> login result: $result');

      if (result['ok'] == true) {
        final data = result['data'] ?? {};
        final prefs = await SharedPreferences.getInstance();

        final String name = data['name'] ?? data['username'] ?? '';
        final String userId = data['userId']?.toString() ?? data['id']?.toString() ?? '';
        final String userEmail = data['email'] ?? email;
        final String role = data['role'] ?? '';

        final dynamic rawActive = data['isActive'];
        final bool isActive = parseBool(rawActive);

        final String loginTimeIso = DateTime.now().toIso8601String();

        // Persist User Info (Non-Sensitive)
        if (userId.isNotEmpty) await prefs.setString('user_id', userId);
        if (name.isNotEmpty) await prefs.setString('user_name', name);
        if (userEmail.isNotEmpty) await prefs.setString('user_email', userEmail);
        if (role.isNotEmpty) await prefs.setString('user_role', role);
        await prefs.setBool('user_is_active', isActive);
        await prefs.setString('user_login_time', loginTimeIso);

        // NOTE: JWT Token is already handled inside api.login() -> saveToken()

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomePage(
              userName: name.isNotEmpty ? name : 'Operator',
              userEmail: userEmail,
              role: role,
              isActive: isActive,
              loginTime: DateTime.parse(loginTimeIso),
            ),
          ),
        );
      } else {
        final msg = result['message'] ?? 'Login failed';
        setState(() {
          _error = msg;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $msg')));
        }
      }
    } catch (e) {
      devLog('auth.dart -> unexpected exception in _signIn: $e');
      setState(() {
        _error = 'Unexpected error: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unexpected error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Widget _buildLoginCard(BuildContext context, double parentWidth) {
    final double horizontalPadding = (parentWidth > 420) ? 34 : 20;
    const double verticalPadding = 28;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, minWidth: 280),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'User Login',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                  const SizedBox(height: 24),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Email', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.validateEmail,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      hintText: 'someone@example.com',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    validator: (v) => (v == null || v.isEmpty) ? 'Password required' : null,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      hintText: 'Shhhh...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Checkbox(
                        value: _showPassword,
                        onChanged: (bool? value) {
                          setState(() {
                            _showPassword = value ?? false;
                          });
                        },
                      ),
                      const Text('Show Password'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.indigo[800],
                      ),
                      child: _loading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white)
                        ),
                      )
                          : const Text(
                        'Sign In',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo[50],
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double height = constraints.maxHeight;
            final double width = constraints.maxWidth;
            // Adjusted spacing logic to prevent overflow on small screens
            final double topSpacing = (height * 0.14).clamp(24.0, 150.0);
            final double bottomSpacing = (height * 0.08).clamp(20.0, 100.0);
            final double statusBarHeight = MediaQuery.of(context).padding.top;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(height: statusBarHeight, width: double.infinity, color: Colors.white),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    child: Row(
                      children: [
                        // Safe image loading
                        Image.asset('assets/logo.png', height: 40, errorBuilder: (c, o, s) => const Icon(Icons.security, size: 40, color: Colors.indigo)),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Netra Sarthi',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
                              Text('Secure Surveillance Portal',
                                  style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        SizedBox(height: topSpacing),
                        _buildLoginCard(context, width),
                        SizedBox(height: bottomSpacing),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}