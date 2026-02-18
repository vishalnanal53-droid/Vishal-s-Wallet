// ─── login_page.dart ────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'firebase_service.dart';

// ── Dark Theme Color Palette ──────────────────────────────────────────────────
const _kBg        = Color(0xFF1A1B2E); // Deep dark navy background
const _kCard      = Color(0xFF242535); // Card surface
const _kCardBorder= Color(0xFF2E2F45); // Subtle card border
const _kAccent    = Color(0xFF7C3AED); // Vivid purple accent
const _kAccent2   = Color(0xFF8B5CF6); // Lighter purple
const _kTextPrim  = Color(0xFFFFFFFF); // Primary text
const _kTextSec   = Color(0xFFA0A3BD); // Secondary / muted text
const _kInputBg   = Color(0xFF1E1F32); // Input field background
const _kInputBorder= Color(0xFF3A3B52);// Input border

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isSignUp = false;
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;

  final _fb = FirebaseService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _error = null; _loading = true; });
    try {
      if (_isSignUp) {
        await _fb.signUp(_emailController.text.trim(), _passwordController.text, _usernameController.text.trim());
      } else {
        await _fb.signIn(_emailController.text.trim(), _passwordController.text);
      }
    } catch (err) {
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1B2E), Color(0xFF16172A), Color(0xFF1E1040)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _kCardBorder, width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(100), blurRadius: 40, offset: const Offset(0, 20)),
                  BoxShadow(color: const Color(0xFF7C3AED).withAlpha(30), blurRadius: 60, offset: const Offset(0, 10)),
                ],
              ),
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withAlpha(80), blurRadius: 20, offset: const Offset(0, 8))],
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 32),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFC4B5FD)],
                      ).createShader(bounds),
                      child: const Text(
                        'KasuBook',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Your Personal Money Manager',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _kTextSec, fontSize: 14),
                    ),
                    const SizedBox(height: 32),

                    // Username (sign-up only)
                    if (_isSignUp) ...[
                      _label('Username'),
                      _textField(_usernameController, 'Choose a username', validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Username is required';
                        return null;
                      }),
                      const SizedBox(height: 16),
                    ],

                    // Email
                    _label('Email'),
                    _textField(_emailController, 'Enter your email',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email is required';
                        if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password
                    _label('Password'),
                    _textField(_passwordController, 'Enter your password',
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: _kTextSec,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Error
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B1919),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF7F1D1D).withAlpha(100)),
                        ),
                        child: Text(_error!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13)),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Submit button
                    SizedBox(
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withAlpha(80), blurRadius: 20, offset: const Offset(0, 8))],
                        ),
                        child: ElevatedButton(
                          onPressed: _loading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            _loading ? 'Please wait...' : (_isSignUp ? 'Sign Up' : 'Sign In'),
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Toggle
                    GestureDetector(
                      onTap: () => setState(() { _isSignUp = !_isSignUp; _error = null; }),
                      child: Text(
                        _isSignUp ? 'Already have an account? Sign In' : "Don't have an account? Sign Up",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _kAccent2, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextSec)),
  );

  Widget _textField(
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    obscureText: obscureText,
    validator: validator,
    style: const TextStyle(color: _kTextPrim, fontSize: 14),
    decoration: InputDecoration(
      suffixIcon: suffixIcon,
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF5C5E7A)),
      filled: true,
      fillColor: _kInputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kInputBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kInputBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kAccent, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFEF4444))),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2)),
      errorStyle: const TextStyle(color: Color(0xFFFCA5A5)),
    ),
  );
}