import 'package:flutter/material.dart';
import '../utils/colors.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/ri.dart'; // Google icon
import 'package:iconify_flutter/icons/ic.dart'; // Email icon
import 'signup.dart';
import 'otp_verification.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  // === Backend Integration Variables ===
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Your API base URL - replace with your actual backend URL
  final String _baseUrl = 'http://localhost:8000';

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

  // === Backend Integration: Send Login OTP Function ===
  // This matches your send_login_otp backend function
  Future<void> _sendSmsToBackend(String mobileNumber) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/send-login-otp'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'mobile_number': mobileNumber,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // SMS sent successfully - navigate to OTP screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationScreen(
              mobileNumber: mobileNumber,
              purpose: AuthPurpose.login,
            ),
          ),
        );
        
        // Show success message with hardcoded OTP
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent successfully! Enter: 111111'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _errorMessage = responseData['detail'] ?? 'Failed to send OTP';
        });
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error. Please check your connection.';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // === Backend Integration: Check if user exists ===
  // This matches your get_user_by_mobile backend function
  Future<bool> _checkUserExists(String mobileNumber) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/check-mobile?mobile_number=$mobileNumber'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['success'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error checking user: $e');
      return false;
    }
  }

  // Called when user taps "Send SMS"
  void _handleSendSms() async {
    if (_formKey.currentState!.validate()) {
      final phone = '+63${_phoneController.text.trim()}';
      final phoneCode = _phoneController.text.trim();
      print("Send SMS to: $phone");


      // === Backend Integration: Check if user exists first ===
      bool userExists = await _checkUserExists(phoneCode);
      
      if (!userExists) {
        // User doesn't exist - show error and suggest signup
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Mobile number not registered. Please sign up first.'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Sign Up',
              textColor: Colors.white,
              onPressed: _goToSignup,
            ),
          ),
        );
        return;
      }

      // === Backend Integration: Send SMS OTP ===
      await _sendSmsToBackend(phone);
    }
  }

  // Called when Google login icon is tapped
  void _handleGoogleLogin() async {
    // === TODO: Backend Hook Here ===
    // Trigger Google Sign-In logic (Firebase, OAuth, etc.)
    print("Google login pressed");
    
    setState(() {
      _isLoading = true;
    });

    try {
      // === Backend Integration: Google OAuth Login ===
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/google-login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          // Add Google OAuth token here
          'google_token': 'your_google_oauth_token',
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        // Handle successful Google login
        print('Google login successful: $responseData');
        
        // Navigate to home screen or handle login success
        // Navigator.pushReplacementNamed(context, '/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google login failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Google login error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error during Google login.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Called when email login icon is tapped
  void _handleEmailLogin() async {
    // === TODO: Backend Hook Here ===
    // Trigger Email-based login flow
    print("Email login pressed");
    
    // Show email login dialog or navigate to email login screen
    _showEmailLoginDialog();
  }

  // === Backend Integration: Email Login Dialog ===
  void _showEmailLoginDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Email Login'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // === Backend Integration: Email Login ===
                await _loginWithEmail(
                  emailController.text.trim(),
                  passwordController.text,
                );
                Navigator.of(context).pop();
              },
              child: const Text('Login'),
            ),
          ],
        );
      },
    );
  }

  // === Backend Integration: Email Login Function ===
  Future<void> _loginWithEmail(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both email and password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/login-email'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // Email login successful
        print('Email login successful: $responseData');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to home screen
        // Navigator.pushReplacementNamed(context, '/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['detail'] ?? 'Email login failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error during email login.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

                      // === Error Message Display ===
                      if (_errorMessage.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _errorMessage,
                            style: TextStyle(color: Colors.red.shade700),
                            textAlign: TextAlign.center,
                          ),
                        ),

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
                                    enabled: !_isLoading, // Disable during loading
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
                          onPressed: _isLoading ? null : _handleSendSms, // Disable during loading
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isLoading ? Colors.grey : Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
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
                            onTap: _isLoading ? null : _handleGoogleLogin, // Disable during loading
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: _isLoading ? Colors.grey : Colors.blueAccent),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Iconify(
                                Ri.google_fill,
                                size: 28,
                                color: _isLoading ? Colors.grey : Colors.blueAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),

                          // Email Login
                          GestureDetector(
                            onTap: _isLoading ? null : _handleEmailLogin, // Disable during loading
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: _isLoading ? Colors.grey : Colors.blueAccent),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Iconify(
                                Ic.baseline_email,
                                size: 28,
                                color: _isLoading ? Colors.grey : Colors.blueAccent,
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
                            onTap: _isLoading ? null : _goToSignup, // Disable during loading
                            child: Text(
                              "Signup",
                              style: TextStyle(
                                color: _isLoading ? Colors.grey : Colors.deepOrange,
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

            // === Loading Overlay ===
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}