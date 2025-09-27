import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_app/utils/color.dart';

import '../home_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  late Timer _timer;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _canResendEmail = false;
  int _cooldownTime = 60;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    startCooldownTimer();

    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      checkEmailVerified();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }
  /// Start cooldown for "Resend Email" button
  void startCooldownTimer() {
    _canResendEmail = false;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownTime == 0) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _canResendEmail = true;
            _cooldownTime = 60;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _cooldownTime--;
          });
        }
      }
    });
  }

  /// Check if current user has verified email
  Future<void> checkEmailVerified() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    await user.reload();
    user = _auth.currentUser;

    if (user?.emailVerified ?? false) {
      _timer.cancel();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Email successfully verified!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  /// Resend verification email
  Future<void> resendVerificationEmail() async {
    if (!_canResendEmail) return;

    try {
      await _auth.currentUser?.sendEmailVerification();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("A new verification email has been sent."),
            backgroundColor: Colors.blue,
          ),
        );
        startCooldownTimer();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? "Failed to send email."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Verify Your Email"),
        backgroundColor: AppColor.primaryColor,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.mark_email_read_outlined,
                size: 100,
                color: AppColor.primaryColor,
              ),
              const SizedBox(height: 30),
              const Text(
                "Check Your Mailbox",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                "We have sent a verification link to your email address:",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 5),
              Text(
                _auth.currentUser?.email ?? 'your email',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColor.primaryColor,
                ),
              ),
              const SizedBox(height: 30),
              CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColor.primaryColor,
              ),
              const SizedBox(height: 15),
              Text(
                "Waiting for verification...",
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),
              // Resend Email Button
              ElevatedButton(
                onPressed: _canResendEmail ? resendVerificationEmail : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: AppColor.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade500,
                ),
                child: Text(
                  _canResendEmail
                      ? "Resend Email"
                      : "Resend in ($_cooldownTime s)",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              // Switch account
              TextButton(
                onPressed: () async {
                  await _auth.signOut();
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/', (route) => false);
                },
                child: Text(
                  "Use a different email",
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
