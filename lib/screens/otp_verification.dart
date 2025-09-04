import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../main.dart';
import '../services/authenticated_api_service.dart';

// Firebase Auth imports
import 'package:firebase_auth/firebase_auth.dart';

enum AuthPurpose { login, signup }

class OTPVerificationScreen extends StatefulWidget {
  final String? firstName;
  final String? lastName;
  final String mobileNumber;
  final AuthPurpose purpose;
  final String? verificationId; // Firebase verification ID

  const OTPVerificationScreen({
    super.key,
    this.firstName,
    this.lastName,
    required this.mobileNumber,
    required this.purpose,
    this.verificationId, // Required for Firebase Auth
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  final _otpFocusNodes = List.generate(6, (_) => FocusNode());

  int _resendTimer = 60;
  bool _canResend = false;
  bool _isLoading = false;

  // Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Backend URL
  String get _baseUrl {
    if (Platform.isAndroid) {
      return 'http://192.168.100.144:8000';
    } else {
      return 'http://10.0.2.2:8000';
    }
  }

  @override
  void initState() {
    super.initState();
    _startResendTimer();

    // Validate that we have the required verificationId for Firebase auth
    if (widget.verificationId == null) {
      print('Warning: No verification ID provided for OTP verification');
    }
  }

  @override
  void dispose() {
    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendTimer = 60;
      _canResend = false;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (_resendTimer > 0 && mounted) {
        setState(() => _resendTimer--);
        _startResendTimer();
      } else if (mounted) {
        setState(() => _canResend = true);
      }
    });
  }

  void _onOTPDigitChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    } else if (index == 5) {
      _otpFocusNodes[index].unfocus();
    }
  }

  // MAIN VERIFICATION METHOD - Firebase Auth first
  Future<void> _verifyOTP() async {
    if (!_formKey.currentState!.validate()) return;

    final otp = _otpControllers.map((c) => c.text).join();

    if (otp.length != 6) {
      _showSnackBar('Please enter all 6 digits', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _verifyWithFirebase(otp);
    } catch (e) {
      print('Error during OTP verification: $e');
      _showSnackBar('Network error. Please check your connection.', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Firebase Auth Verification
  Future<void> _verifyWithFirebase(String otp) async {
    if (widget.verificationId == null) {
      _showSnackBar(
        'Verification session expired. Please go back and try again.',
        Colors.red,
      );
      return;
    }

    try {
      // Create phone auth credential
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId!,
        smsCode: otp,
      );

      // Sign in with credential
      UserCredential result = await _auth.signInWithCredential(credential);

      if (result.user != null) {
        // Get Firebase ID token
        String? idToken = await result.user!.getIdToken();

        if (idToken != null) {
          if (widget.purpose == AuthPurpose.signup) {
            // For signup, create user in backend
            await _createUserInBackend(idToken);
          } else {
            // For login, user is already authenticated with Firebase
            await _handleSuccessfulLogin();
          }
        } else {
          _showSnackBar('Authentication failed. Please try again.', Colors.red);
        }
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase verification error: ${e.code} - ${e.message}');

      String errorMessage;
      switch (e.code) {
        case 'invalid-verification-code':
          errorMessage = 'Invalid OTP. Please check and try again.';
          break;
        case 'session-expired':
        case 'credential-already-in-use':
          errorMessage = 'OTP has expired. Please request a new code.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Please try again later.';
          break;
        default:
          errorMessage = 'Verification failed. Please try again.';
      }

      _showSnackBar(errorMessage, Colors.red);

      // Clear OTP fields for retry
      _clearOTPFields();
    } catch (e) {
      print('Unexpected error during verification: $e');
      _showSnackBar(
        'An unexpected error occurred. Please try again.',
        Colors.red,
      );
      _clearOTPFields();
    }
  }

  // Create user in backend after Firebase verification (for signup)
  Future<void> _createUserInBackend(String idToken) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/create-firebase-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebase_id_token': idToken,
          'additional_info': {
            'first_name': widget.firstName ?? '',
            'last_name': widget.lastName ?? '',
            'mobile_number': widget.mobileNumber.replaceAll('+63', ''),
          },
        }),
      );

      print('Backend user creation response: ${response.statusCode}');
      print('Backend response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _handleSuccessfulSignup();
      } else {
        final errorData = jsonDecode(response.body);
        String errorMessage = errorData['detail'] ?? 'Failed to create account';

        // If user already exists, treat as success
        if (errorMessage.contains('already registered') ||
            errorMessage.contains('already exists')) {
          await _handleSuccessfulSignup();
        } else {
          _showSnackBar(errorMessage, Colors.red);
          _clearOTPFields();
        }
      }
    } catch (e) {
      print('Backend user creation error: $e');
      _showSnackBar('Failed to create account. Please try again.', Colors.red);
      _clearOTPFields();
    }
  }

  // Handle successful login - simplified
  Future<void> _handleSuccessfulLogin() async {
    final otp = _otpControllers.map((c) => c.text).join();

    // Use simple client-side verification
    final success = await SimpleApiService.verifyOTP(
      phoneNumber: widget.mobileNumber,
      otp: otp,
      firstName: widget.firstName,
      lastName: widget.lastName,
    );

    if (success) {
      _showSnackBar('Login successful!', Colors.green);

      // Navigate to main screen
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      }
    } else {
      _showSnackBar('Invalid OTP. Please try again.', Colors.red);
      _clearOTPFields();
    }
  }

  // Handle successful signup - simplified
  Future<void> _handleSuccessfulSignup() async {
    final otp = _otpControllers.map((c) => c.text).join();

    // Use simple client-side verification
    final success = await SimpleApiService.verifyOTP(
      phoneNumber: widget.mobileNumber,
      otp: otp,
      firstName: widget.firstName,
      lastName: widget.lastName,
    );

    if (success) {
      _showSnackBar('Account created successfully!', Colors.green);

      // Navigate to main screen
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      }
    } else {
      _showSnackBar('Invalid OTP. Please try again.', Colors.red);
      _clearOTPFields();
    }
  }

  // Resend OTP - trigger new Firebase verification
  Future<void> _resendOTP() async {
    if (!_canResend) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // For resend, we need to trigger new Firebase phone verification
      // This should be done from the parent screen
      _showSnackBar(
        'Please go back and request a new verification code',
        Colors.orange,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearOTPFields() {
    for (final controller in _otpControllers) {
      controller.clear();
    }
    if (mounted) {
      _otpFocusNodes[0].requestFocus();
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _goBack() => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    final isLogin = widget.purpose == AuthPurpose.login;
    final hasValidVerificationId = widget.verificationId != null;

    return Stack(
      children: [
        // Background Image
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/otp_bg.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),

        // Main content
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: _goBack,
            ),
            title: Text(
              isLogin ? 'Login Verification' : 'Complete Registration',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    // Title
                    Text(
                      isLogin ? 'Verify to Login' : 'Enter Verification Code',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Subtitle
                    Text(
                      'We sent a 6-digit code to\n${widget.mobileNumber}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),

                    // Firebase Auth indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: hasValidVerificationId
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        border: Border.all(
                          color: hasValidVerificationId
                              ? Colors.green.shade200
                              : Colors.red.shade200,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasValidVerificationId
                                ? Icons.security
                                : Icons.warning,
                            size: 16,
                            color: hasValidVerificationId
                                ? Colors.green.shade600
                                : Colors.red.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hasValidVerificationId
                                ? 'Secured by Firebase Auth'
                                : 'Session expired - go back',
                            style: TextStyle(
                              fontSize: 12,
                              color: hasValidVerificationId
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // OTP Input Fields
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        6,
                        (i) => _buildOTPField(
                          controller: _otpControllers[i],
                          focusNode: _otpFocusNodes[i],
                          index: i,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Verify Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isLoading || !hasValidVerificationId)
                            ? null
                            : _verifyOTP,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isLoading || !hasValidVerificationId
                              ? Colors.grey
                              : Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                hasValidVerificationId
                                    ? 'Verify OTP'
                                    : 'Session Expired',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Resend section
                    if (hasValidVerificationId)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Didn't receive the code? "),
                          _canResend
                              ? GestureDetector(
                                  onTap: _isLoading ? null : _resendOTP,
                                  child: Text(
                                    'Get new code',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _isLoading
                                          ? Colors.grey
                                          : Colors.blue,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Resend in ${_resendTimer}s',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                        ],
                      ),

                    const Spacer(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOTPField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required int index,
  }) {
    return SizedBox(
      width: 50,
      height: 60,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withOpacity(0.9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          contentPadding: const EdgeInsets.all(0),
        ),
        onChanged: (value) => _onOTPDigitChanged(value, index),
        validator: (value) => (value == null || value.isEmpty) ? '' : null,
      ),
    );
  }
}
