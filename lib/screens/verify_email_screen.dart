import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isSending = false;
  bool _isChecking = false;

  Future<void> _sendVerification() async {
    setState(() => _isSending = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _checkVerified() async {
    setState(() => _isChecking = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _sendVerification();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 56,
                  color: Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Verify Your Email',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'We sent a verification email to $email. '
                'Please verify your email to continue.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isSending ? null : _sendVerification,
                child: _isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Color(0xFF4CAF50),
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Resend email',
                        style: TextStyle(color: Color(0xFF4CAF50)),
                      ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _checkVerified,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'I\'ve verified my email',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => auth.signOut(),
                child: const Text(
                  'Use a different account',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
