import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_app/screen/home_screen.dart';
import 'package:web_socket_app/screen/auth_screen/signup_screen.dart';
import 'package:web_socket_app/utils/color.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// ================= LOGIN =================
  Future<void> login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;
      if (user != null) {
        await user.reload();
        user = _auth.currentUser;

        if (user!.emailVerified) {
          String? fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({
                  'fcmToken': fcmToken,
                  'email': user.email,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
          }

          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Your email is not verified"),
                action: SnackBarAction(
                  label: "Resend",
                  onPressed: () async {
                    await user?.sendEmailVerification();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Verification email sent again"),
                      ),
                    );
                  },
                ),
              ),
            );
          }
          await _auth.signOut();
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case "user-not-found":
          errorMessage = "No user found with this email.";
          break;
        case "wrong-password":
        case "invalid-credential":
          errorMessage = "Incorrect password or invalid credentials.";
          break;
        default:
          errorMessage = e.message ?? "Login failed.";
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ================= VALIDATORS =================
  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return "Enter your email.";
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$');
    if (!emailRegex.hasMatch(value)) {
      return "Enter a valid Gmail address.";
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return "Enter your password.";
    if (value.length < 6) return "Password must be at least 6 characters.";
    return null;
  }

  /// ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(
                child: Image.asset(
                  "assets/image/chat.png",
                  color: AppColor.primaryColor,
                  height: 100,
                  width: 100,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Chatter",
                style: TextStyle(
                  color: AppColor.primaryColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 25),

              /// Email
              TextFormField(
                controller: _emailController,
                validator: validateEmail,
                decoration: InputDecoration(
                  hintText: "Email",
                  prefixIcon: Icon(Icons.email, color: AppColor.primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              /// Password
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                validator: validatePassword,
                decoration: InputDecoration(
                  hintText: "Password",
                  prefixIcon: Icon(Icons.lock, color: AppColor.primaryColor),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppColor.primaryColor,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              /// Login button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColor.primaryColor,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _isLoading ? null : login,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "SIGN IN",
                        style: TextStyle(color: Colors.white),
                      ),
              ),

              const SizedBox(height: 15),

              /// Signup link
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignupScreen(),
                    ),
                  );
                },
                child: const Text(
                  "or create an account",
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
