import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../home_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  late Timer _timer;
  final FirebaseAuth _auth = FirebaseAuth.instance;


  bool _canResendEmail = true;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();

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

  Future<void> checkEmailVerified() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    await user.reload();
    user = _auth.currentUser;

    if (user?.emailVerified ?? false) {
      _timer.cancel();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Email successfully verified!"), backgroundColor: Colors.green,)
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
        );
      }
    }
  }

  Future<void> resendVerificationEmail() async {

    if (!_canResendEmail) return;

    try {
      await _auth.currentUser?.sendEmailVerification();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("A new verification email has been sent."), backgroundColor: Colors.blue,)
        );


        setState(() {
          _canResendEmail = false;
        });

        _cooldownTimer = Timer(const Duration(seconds: 60), () {
          if (mounted) {
            setState(() {
              _canResendEmail = true;
            });
          }
        });
      }
    } on FirebaseAuthException catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message ?? "Failed to send email."), backgroundColor: Colors.red)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify Your Email"),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "A verification link has been sent to your email: ${_auth.currentUser?.email ?? 'your email'}",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                "Please check your inbox (and spam folder) and click the link to continue. This page will update automatically.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(

                onPressed: resendVerificationEmail,
                style: ElevatedButton.styleFrom(

                  backgroundColor: _canResendEmail ? Theme.of(context).primaryColor : Colors.grey,
                ),
                child: Text(

                  _canResendEmail ? "Resend Email" : "Wait to Resend",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}