import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/colors.dart';
import 'login.dart';
import 'otp_verification.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/ri.dart';
import 'package:iconify_flutter/icons/ic.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  // createState() creates the mutable state for this widget
  @override
  State<SignupScreen> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignupScreen> {
  // Add your API base URL here
  static const String baseUrl = 'http://localhost:8000';
  
  // Form key - used to validate all form fields at once
  // GlobalKey helps Flutter identify and manage this specific form
  final _formKey = GlobalKey<FormState>();
  // TextEditingControllers - these control the text input fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _mobileController = TextEditingController();
  
  // FocusNode to track mobile input focus state
  final _mobileFocusNode = FocusNode();
  bool _isMobileFocused = false;
  bool _isLoading = false; // Add loading state

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

  // dispose() is called when this page is removed from memory
  // We need to clean up our controllers to prevent memory leaks
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    _mobileFocusNode.dispose();
    super.dispose(); // Always call super.dispose() last
  }

  // Updated _sendSMS function with HTTP call
  Future<void> _sendSMS() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true; // Show loading
      });

      String firstName = _firstNameController.text;
      String lastName = _lastNameController.text;
      String mobileNumber = '+63${_mobileController.text}';

      print('First Name: $firstName');
      print('Last Name: $lastName');
      print('Mobile: $mobileNumber');

      try {
        // Make HTTP call to send SMS
        final response = await http.post(
          Uri.parse('$baseUrl/users/send-sms'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'mobile_number': mobileNumber,
          }),
        );

        if (response.statusCode == 200) {
          // Success - navigate to OTP screen and pass signup data + purpose
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OTPVerificationScreen(
                  firstName: firstName,
                  lastName: lastName,
                  mobileNumber: mobileNumber,
                  purpose: AuthPurpose.signup,
                ),
              ),
            );
          }
        } else {
          // Handle error response
          final errorData = jsonDecode(response.body);
          _showErrorSnackBar(errorData['detail'] ?? 'Failed to send SMS');
        }
      } catch (e) {
        // Handle network or other errors
        _showErrorSnackBar('Network error. Please check your connection.');
        print('Error sending SMS: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false; // Hide loading
          });
        }
      }
    }
  }

  // Helper method to show error messages
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _signInWithGoogle() {
    print('Google sign-in');
  }

  void _signInWithEmail() {
    print('Email sign-in');
  }

  void _navigateToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
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
            // Background Image
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/bg.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Main Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 60),

                      // TITLE SECTION
                      const Text(
                        'Register',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: kBlack,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 50),

                      // FIRST NAME SECTION
                      const Text(
                        'First Name',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _firstNameController,
                        enabled: !_isLoading, // Disable when loading
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: kBrightBlue),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your first name';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // LAST NAME SECTION
                      const Text(
                        'Last Name',
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _lastNameController,
                        enabled: !_isLoading, // Disable when loading
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: kBrightBlue),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your last name';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // MOBILE NUMBER SECTION
                      const Text(
                        'Mobile Number',
                        style: TextStyle(fontSize: 16, color: kBlack),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 56,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _isMobileFocused ? Colors.blue : Colors.grey,
                            width: 1.0,
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
                              height: 28,
                              color: Colors.grey,
                              margin: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            Expanded(
                              child: TextFormField(
                                controller: _mobileController,
                                focusNode: _mobileFocusNode,
                                enabled: !_isLoading, // Disable when loading
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your mobile number';
                                  }
                                  if (value.length != 10) {
                                    return 'Please enter exactly 10 digits';
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
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // SEND SMS BUTTON - Updated with loading state
                      ElevatedButton(
                        onPressed: _isLoading ? null : _sendSMS, // Disable when loading
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBrightBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Send SMS',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),

                      const SizedBox(height: 30),

                      // "OR" DIVIDER
                      const Text(
                        'or',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 30),

                      // SOCIAL LOGIN BUTTONS SECTION
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // GOOGLE SIGN-IN BUTTON
                          GestureDetector(
                            onTap: _isLoading ? null : _signInWithGoogle,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                border: Border.all(color: kBrightBlue),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Iconify(
                                  Ri.google_fill,
                                  size: 28,
                                  color: kBrightBlue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          // EMAIL SIGN-IN BUTTON
                          GestureDetector(
                            onTap: _isLoading ? null : _signInWithEmail,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                border: Border.all(color: kBrightBlue),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Iconify(
                                  Ic.baseline_email,
                                  size: 28,
                                  color: kBrightBlue,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // LOGIN LINK AT THE BOTTOM
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Already have an account? ',
                            style: TextStyle(fontSize: 16, color: kBlack),
                          ),
                          GestureDetector(
                            onTap: _isLoading ? null : _navigateToLogin,
                            child: const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 16,
                                color: kBrightOrange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),
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