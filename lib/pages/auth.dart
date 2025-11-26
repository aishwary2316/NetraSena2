// lib/pages/auth.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart'; // Required for Biometrics
import 'package:flutter/foundation.dart'; // For kDebugMode
import '../utils/safe_log.dart';
import '../services/api_service.dart';
import '../utils/validators.dart'; // Required for Regex Validation
import 'home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Make the native status bar transparent so our top container shows through.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  runApp(const AuthPage());
}

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Netra Sarthi Login',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final ApiService api = ApiService();
  final LocalAuthentication auth = LocalAuthentication(); // Biometric Auth

  // Form key to trigger validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _showPassword = false;
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    // 1. INPUT VALIDATION
    // This checks the Validators.validateEmail logic before doing anything else.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    // 2. BIOMETRIC INTERLOCK
    bool isBiometricAuthenticated = false;
    try {
      final bool canCheckBiometrics = await auth.canCheckBiometrics;

      if (canCheckBiometrics) {
        isBiometricAuthenticated = await auth.authenticate(
          localizedReason: 'Officer identity verification required',
          options: const AuthenticationOptions(
            biometricOnly: true, // Strict: Do not allow PIN fallback
            stickyAuth: true,
          ),
        );
      } else {
        // Fallback for devices without hardware (e.g. older phones)
        // In a strict environment, you might disable this 'true' fallback.
        isBiometricAuthenticated = true;
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
        final bool isActive = rawActive == true ||
            rawActive == 1 ||
            rawActive?.toString().trim().toLowerCase() == 'true' ||
            rawActive?.toString().trim() == '1';

        final String loginTimeIso = DateTime.now().toIso8601String();

        if (userId.isNotEmpty) await prefs.setString('user_id', userId);
        if (name.isNotEmpty) await prefs.setString('user_name', name);
        if (userEmail.isNotEmpty) await prefs.setString('user_email', userEmail);
        if (role.isNotEmpty) await prefs.setString('user_role', role);
        await prefs.setBool('user_is_active', isActive);
        await prefs.setString('user_login_time', loginTimeIso);

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomePage(
              userName: name.isNotEmpty ? name : 'Operator',
              userEmail: userEmail,
              role: role,
              isActive: parseBool(data['isActive']),
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
            child: Form( // Wrapped in Form widget for validation
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
                  TextFormField( // Changed to TextFormField
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.validateEmail, // Applied strict email validator
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      hintText: 'someone@example.com',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 8),
                  TextFormField( // Changed to TextFormField
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    // Basic empty check (Injection blocked via Hashing in ApiService)
                    validator: (v) => (v == null || v.isEmpty) ? 'Password required' : null,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      hintText: 'Shhhh...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
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
                  if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
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
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
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
    // NOTE: we set SafeArea(top: false) because we are explicitly drawing a
    // top bar of exact status-bar height so we don't want SafeArea to add extra top padding.
    return Scaffold(
      backgroundColor: Colors.indigo[50],
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double height = constraints.maxHeight;
            final double width = constraints.maxWidth;
            // height reserved for content spacing
            final double topSpacing = (height * 0.14).clamp(24.0, 220.0);
            final double bottomSpacing = (height * 0.08).clamp(20.0, 140.0);

            // exact status bar height
            final double statusBarHeight = MediaQuery.of(context).padding.top;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // This top bar has the same color as the scaffold background
                  // and sits *under* the native status bar because we made it transparent.
                  // This creates the illusion that the status bar is Colors.indigo[50].
                  Container(height: statusBarHeight, width: double.infinity, color: Colors.white),

                  // HEADER: full width, NO outer margin
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        Image.asset('assets/logo.png', height: 50, errorBuilder: (c, o, s) => const SizedBox()),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              //Text('Government of India', style: TextStyle(fontSize: 12, color: Colors.black54)),
                              Text('Netra Sarthi',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Remaining content (keeps internal padding)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
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