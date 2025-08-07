import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

enum AuthPurpose { login, signup }

class OTPVerificationScreen extends StatefulWidget {
  final String? firstName;
  final String? lastName;
  final String mobileNumber;
  final AuthPurpose purpose;

  const OTPVerificationScreen({
    super.key,
    this.firstName,
    this.lastName,
    required this.mobileNumber,
    required this.purpose,
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
  final bool _isLoading = false;
  
  // Backend URL - should match your login screen
  final String _baseUrl = 'http://localhost:8000';

  @override
  void initState() {
    super.initState();
    _startResendTimer();
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

  void _verifyOTP() {
    if (_formKey.currentState!.validate()) {
      final otp = _otpControllers.map((c) => c.text).join();

      // TODO: Hook up backend OTP verification here
      print('OTP: $otp');
      print('Mobile: ${widget.mobileNumber}');
      print('Purpose: ${widget.purpose}');
      print('First Name: ${widget.firstName}');
      print('Last Name: ${widget.lastName}');

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    }
  }

  void _resendOTP() {
    if (_canResend) {
      // TODO: Hook up resend OTP backend logic
      print('Resending OTP to ${widget.mobileNumber}');
      for (final controller in _otpControllers) {
        controller.clear();
      }
      _otpFocusNodes[0].requestFocus();

      _startResendTimer();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP resent successfully!')),
      );
    }
  }

  void _goBack() => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    final isLogin = widget.purpose == AuthPurpose.login;

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

        // Main content with transparent scaffold
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
              isLogin ? 'Login Verification' : 'Signup Verification',
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
                    Text(
                      isLogin ? 'Verify to Login' : 'Enter Verification Code',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'We sent a 6-digit code to\n${widget.mobileNumber}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 40),

                    // OTP Fields
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
                        onPressed: _verifyOTP,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Verify OTP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Resend Text
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Didn't receive the code? "),
                        _canResend
                            ? GestureDetector(
                                onTap: _resendOTP,
                                child: const Text(
                                  'Resend',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue,
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

                    // Optional user name display
                    if (widget.firstName != null && widget.lastName != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Verifying for:',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.firstName} ${widget.lastName}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          contentPadding: const EdgeInsets.all(0),
        ),
        onChanged: (value) => _onOTPDigitChanged(value, index),
        validator: (value) => (value == null || value.isEmpty) ? '' : null,
      ),
    );
  }
}
