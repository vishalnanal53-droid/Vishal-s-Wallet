import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── Dark Theme Color Palette ────────────────────────────────────────────────
const _kBg          = Color(0xFF1A1B2E);
const _kCard        = Color(0xFF242535);
const _kAccent      = Color(0xFF7C3AED);
const _kTextPrim    = Color(0xFFFFFFFF);
const _kTextSec     = Color(0xFFA0A3BD);
const _kRed         = Color(0xFFEF4444);
const _kGreen       = Color(0xFF22C55E);
const _kOrange      = Color(0xFFF97316);
const _kInputBg     = Color(0xFF1E1F32);
const _kInputBorder = Color(0xFF3A3B52);

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

enum _Step { email, sent }

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _emailFormKey    = GlobalKey<FormState>();

  _Step   _step      = _Step.email;
  bool    _isLoading = false;
  String? _sentEmail;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() {
        _sentEmail = email;
        _step      = _Step.sent;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'user-not-found') {
        _showSnack('No account found with this email.', isError: true);
      } else {
        setState(() {
          _sentEmail = email;
          _step      = _Step.sent;
        });
      }
    } catch (_) {
      if (mounted) _showSnack('Something went wrong. Try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _kRed : _kGreen,
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _kTextPrim),
          onPressed: () {
            if (_step == _Step.sent) {
              setState(() => _step = _Step.email);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text('Reset Password',
            style: TextStyle(color: _kTextPrim, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.08, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: _step == _Step.email ? _buildEmailStep() : _buildSentStep(),
          ),
        ),
      ),
    );
  }

  // ── Step 1: Email Entry ───────────────────────────────────────────────────
  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        key: const ValueKey('email'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF7C3AED).withAlpha(80),
                    blurRadius: 20,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: const Icon(Icons.lock_reset_rounded,
                color: Colors.white, size: 30),
          ),
          const SizedBox(height: 28),
          const Text(
            'Forgot Password?',
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.bold, color: _kTextPrim),
          ),
          const SizedBox(height: 10),
          const Text(
            'Enter the email address linked to your account. We\'ll send a password reset link to it.',
            style: TextStyle(fontSize: 14, color: _kTextSec, height: 1.6),
          ),
          const SizedBox(height: 36),
          _label('Email Address'),
          TextFormField(
            controller: _emailController,
            style: const TextStyle(color: _kTextPrim, fontSize: 14),
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDeco(
              hint: 'Enter your registered email',
              icon: Icons.email_outlined,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(v.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          _primaryButton(label: 'Send Reset Link', onPressed: _sendResetEmail),
        ],
      ),
    );
  }

  // ── Step 2: Sent Confirmation ─────────────────────────────────────────────
  Widget _buildSentStep() {
    return Column(
      key: const ValueKey('sent'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        // ── Success icon
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kGreen.withAlpha(30),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kGreen.withAlpha(80)),
          ),
          child: const Icon(Icons.mark_email_read_rounded,
              color: _kGreen, size: 30),
        ),
        const SizedBox(height: 28),

        const Text(
          'Check Your Email!',
          style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.bold, color: _kTextPrim),
        ),
        const SizedBox(height: 10),
        const Text(
          'A password reset link has been sent to:',
          style: TextStyle(fontSize: 14, color: _kTextSec),
        ),
        const SizedBox(height: 10),

        // ── Email chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _kAccent.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kAccent.withAlpha(80)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.email_outlined, color: _kAccent, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _sentEmail ?? '',
                  style: const TextStyle(
                      color: _kAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Steps box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1F32),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kInputBorder),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepRow(
                number: '1',
                text: 'Open your ',
                highlight: 'Inbox or Spam/Junk folder',
                textAfter: ' and find the reset email',
                isWarning: true,
              ),
              SizedBox(height: 14),
              _StepRow(
                number: '2',
                text: 'Tap the ',
                highlight: '"Reset Password"',
                textAfter: ' link in the email',
                isWarning: false,
              ),
              SizedBox(height: 14),
              _StepRow(
                number: '3',
                text: 'Set your new password in the browser',
                isWarning: false,
              ),
              SizedBox(height: 14),
              _StepRow(
                number: '4',
                text: 'Return here and log in with your new password',
                isWarning: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Spam warning banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kOrange.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kOrange.withAlpha(80)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                        fontSize: 13, color: _kTextSec, height: 1.6),
                    children: [
                      TextSpan(
                        text: 'Email not in inbox? ',
                        style: TextStyle(
                            color: _kOrange, fontWeight: FontWeight.w700),
                      ),
                      TextSpan(
                        text: 'Check your ',
                      ),
                      TextSpan(
                        text: 'Spam / Junk',
                        style: TextStyle(
                            color: _kOrange,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: _kOrange),
                      ),
                      TextSpan(
                        text:
                            ' folder. Sometimes reset emails land there. Mark it as "Not Spam" to receive future emails in inbox.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        _primaryButton(
          label: 'Back to Login',
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(height: 16),

        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _step = _Step.email;
              _emailController.clear();
            }),
            child: const Text(
              "Didn't receive it? Try again",
              style: TextStyle(
                  color: _kAccent, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: _kTextSec)),
      );

  InputDecoration _inputDeco(
          {required String hint, required IconData icon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF5C5E7A)),
        filled: true,
        fillColor: _kInputBg,
        prefixIcon: Icon(icon, color: _kTextSec, size: 20),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kInputBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kInputBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kAccent, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kRed)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kRed, width: 2)),
        errorStyle: const TextStyle(color: Color(0xFFFCA5A5)),
      );

  Widget _primaryButton(
          {required String label, required VoidCallback onPressed}) =>
      SizedBox(
        width: double.infinity,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF7C3AED).withAlpha(80),
                  blurRadius: 20,
                  offset: const Offset(0, 8))
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
          ),
        ),
      );
}

// ── Numbered step widget with optional highlight ──────────────────────────────
class _StepRow extends StatelessWidget {
  final String number;
  final String text;
  final String? highlight;
  final String? textAfter;
  final bool isWarning;

  const _StepRow({
    required this.number,
    required this.text,
    this.highlight,
    this.textAfter,
    required this.isWarning,
  });

  @override
  Widget build(BuildContext context) {
    final highlightColor = isWarning ? _kOrange : _kAccent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Number circle
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _kAccent.withAlpha(40),
            shape: BoxShape.circle,
          ),
          child: Text(number,
              style: const TextStyle(
                  color: _kAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: highlight != null
              ? RichText(
                  text: TextSpan(
                    style: const TextStyle(
                        color: _kTextSec, fontSize: 13, height: 1.5),
                    children: [
                      TextSpan(text: text),
                      TextSpan(
                        text: highlight,
                        style: TextStyle(
                          color: highlightColor,
                          fontWeight: FontWeight.w700,
                          backgroundColor: highlightColor.withAlpha(25),
                        ),
                      ),
                      if (textAfter != null) TextSpan(text: textAfter),
                    ],
                  ),
                )
              : Text(text,
                  style: const TextStyle(
                      color: _kTextSec, fontSize: 13, height: 1.5)),
        ),
      ],
    );
  }
}