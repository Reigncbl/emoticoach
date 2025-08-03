import 'package:flutter/material.dart';
import '../utils/colors.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/ri.dart'; // Google icon
import 'package:iconify_flutter/icons/ic.dart'; // Email icon
import 'signup.dart';
import 'otp_verification.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Controller for phone number input
  final TextEditingController _phoneController = TextEditingController();
  
  // FocusNode to track mobile input focus state
  final _mobileFocusNode = FocusNode();
  bool _isMobileFocused = false;

  @override
  void initState() {
    super.initState();
    // Listen to focus changes
    _mobileFocusNode.addListener(() {
      setState(() {
        _isMobileFocused = _mobileFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _mobileFocusNode.dispose();
    super.dispose();
  }

  // Called when user taps "Send SMS"
  void _handleSendSms() {
    if (_formKey.currentState!.validate()) {
      final phone = '+63${_phoneController.text.trim()}';
      print("Send SMS to: $phone");

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OTPVerificationScreen(
            mobileNumber: phone,
            purpose: AuthPurpose.login,
          ),
        ),
      );
    }
  }

  // Called when Google login icon is tapped
  void _handleGoogleLogin() {
    // === TODO: Backend Hook Here ===
    // Trigger Google Sign-In logic (Firebase, OAuth, etc.)
    print("Google login pressed");
  }

  // Called when email login icon is tapped
  void _handleEmailLogin() {
    // === TODO: Backend Hook Here ===
    // Trigger Email-based login flow
    print("Email login pressed");
  }

  // Navigate to Signup screen
  void _goToSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          children: [
            // === Background Image ===
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/bg.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // === Foreground Login Form ===
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 120), // Add top spacing
                      
                      // Login Title
                      const Text(
                        "Login",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: kBlack,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      const Text(
                        "Good to have you back!",
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 50),

                      // === Phone Number Input Field ===
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Mobile Number", style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _isMobileFocused ? Colors.blue : Colors.grey,
                                width: _isMobileFocused ? 2.0 : 1.0,
                              ),
                              borderRadius: BorderRadius.circular(8.0),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: const Center(
                                    child: Text('+63'),
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 24, // Centered divider - half the container height
                                  color: Colors.grey, // Keep divider grey always
                                  margin: const EdgeInsets.symmetric(vertical: 12), // Centers the divider vertically
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    focusNode: _mobileFocusNode,
                                    keyboardType: TextInputType.number,
                                    maxLength: 10,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Enter your mobile number';
                                      }
                                      if (value.length != 10) {
                                        return 'Enter exactly 10 digits';
                                      }
                                      return null;
                                    },
                                    decoration: const InputDecoration(
                                      counterText: '',
                                      hintText: '9123456789',
                                      hintStyle: TextStyle(color: Colors.grey),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // === Send SMS Button ===
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _handleSendSms,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          child: const Text(
                            "Send SMS",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Divider Text
                      const Text("or",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 16),

                      // === Social Login Buttons ===
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Google Login
                          GestureDetector(
                            onTap: _handleGoogleLogin,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.blueAccent),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Iconify(
                                Ri.google_fill,
                                size: 28,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),

                          // Email Login
                          GestureDetector(
                            onTap: _handleEmailLogin,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.blueAccent),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Iconify(
                                Ic.baseline_email,
                                size: 28,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 50),

                      // === Signup Redirect ===
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account yet? "),
                          GestureDetector(
                            onTap: _goToSignup,
                            child: const Text(
                              "Signup",
                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}