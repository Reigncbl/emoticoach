import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/colors.dart';
import 'login.dart';
import 'otp_verification.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/ri.dart';
import 'package:iconify_flutter/icons/ic.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignupScreen> {
  // Add your API base URL here
  static const String baseUrl = 'http://192.168.100.144:8000';
  
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _mobileController = TextEditingController();
  
  final _mobileFocusNode = FocusNode();
  bool _isMobileFocused = false;
  bool _isLoading = false;

  // Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;
  ConfirmationResult? _confirmationResult;

  @override
  void initState() {
    super.initState();
    _mobileFocusNode.addListener(() {
      setState(() {
        _isMobileFocused = _mobileFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    _mobileFocusNode.dispose();
    super.dispose();
  }

  // Updated method to use Firebase Auth for SMS sending
  Future<void> _sendSMS() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      String firstName = _firstNameController.text;
      String lastName = _lastNameController.text;
      String mobileNumber = '+63${_mobileController.text}';

      try {
        // First check if user already exists in your backend
        final checkResponse = await http.get(
          Uri.parse('$baseUrl/users/check-mobile?mobile_number=${_mobileController.text}'),
          headers: {'Content-Type': 'application/json'},
        );

        if (checkResponse.statusCode == 409) {
          _showErrorSnackBar('Mobile number already registered');
          return;
        }

        // Use Firebase Auth to send SMS
        await _auth.verifyPhoneNumber(
          phoneNumber: mobileNumber,
          verificationCompleted: (PhoneAuthCredential credential) async {
            // Auto-verification completed (Android only)
            await _handleAutoVerification(credential, firstName, lastName);
          },
          verificationFailed: (FirebaseAuthException e) {
            _showErrorSnackBar('Failed to send SMS: ${e.message}');
          },
          codeSent: (String verificationId, int? resendToken) {
            // SMS sent successfully, navigate to OTP screen
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OTPVerificationScreen(
                    firstName: firstName,
                    lastName: lastName,
                    mobileNumber: mobileNumber,
                    purpose: AuthPurpose.signup,
                    verificationId: verificationId, // Pass verification ID
                  ),
                ),
              );
            }
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            // Handle timeout
            print('Auto retrieval timeout for verification ID: $verificationId');
          },
          timeout: const Duration(seconds: 60),
        );

      } catch (e) {
        _showErrorSnackBar('Error: ${e.toString()}');
        print('Error sending SMS: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // Handle auto-verification (Android only)
  Future<void> _handleAutoVerification(
    PhoneAuthCredential credential, 
    String firstName, 
    String lastName
  ) async {
    try {
      // Sign in with the credential
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        // Get Firebase ID token
        String? idToken = await userCredential.user!.getIdToken();
        
        if (idToken != null) {
          // Create user in your backend
          await _createUserInBackend(firstName, lastName, idToken);
        }
      }
    } catch (e) {
      _showErrorSnackBar('Auto verification failed: ${e.toString()}');
    }
  }

  // Create user in your backend using Firebase ID token
  Future<void> _createUserInBackend(String firstName, String lastName, String idToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/create-firebase-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebase_id_token': idToken,
          'additional_info': {
            'first_name': firstName,
            'last_name': lastName,
          }
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success - navigate to home or success screen
        if (mounted) {
          // Navigate to your app's main screen
          _showSuccessMessage('Account created successfully!');
        }
      } else {
        final errorData = jsonDecode(response.body);
        _showErrorSnackBar(errorData['detail'] ?? 'Failed to create account');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to create account: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Updated Google Sign-In implementation
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with Firebase
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        // Get Firebase ID token
        String? idToken = await userCredential.user!.getIdToken();
        
        if (idToken != null) {
          // Create user in your backend
          await _createUserInBackend('', '', idToken); // Names will be extracted from Google profile
        }
      }

    } catch (e) {
      _showErrorSnackBar('Google sign-in failed: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
                        enabled: !_isLoading,
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
                        enabled: !_isLoading,
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
                                enabled: !_isLoading,
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

                      // SEND SMS BUTTON
                      ElevatedButton(
                        onPressed: _isLoading ? null : _sendSMS,
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