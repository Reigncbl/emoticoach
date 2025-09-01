import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/colors.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/ri.dart'; // Google icon
import 'package:iconify_flutter/icons/ic.dart'; // Email icon
import 'signup.dart';
import 'otp_verification.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

// Firebase Auth UI imports
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  // Backend Integration Variables
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Device info for security
  String? _deviceInfo;
  String? _userAgent;

  // Firebase Auth variables
  String? _verificationId;
  bool _isPhoneAuthInProgress = false;

  // Fixed base URL - Use your computer's IP address or emulator mapping
  String get _baseUrl {
    if (Platform.isAndroid) {
      // For Android emulator, use special localhost mapping
      return 'http://10.96.80.29:8000';
    } else {
      // For iOS simulator or physical devices, use your computer's IP
      return 'http://10.0.2.2:8000'; // Replace with YOUR actual IP
    }
  }

  @override
  void initState() {
    super.initState();
    // Listen to focus changes
    _mobileFocusNode.addListener(() {
      setState(() {
        _isMobileFocused = _mobileFocusNode.hasFocus;
      });
    });
    
    // Initialize device info
    _initializeDeviceInfo();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _mobileFocusNode.dispose();
    super.dispose();
  }

  // Initialize device information for security
  Future<void> _initializeDeviceInfo() async {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        _deviceInfo = '${androidInfo.brand} ${androidInfo.model}';
        _userAgent = 'Flutter Android/${androidInfo.version.release} (${androidInfo.model})';
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        _deviceInfo = '${iosInfo.name} ${iosInfo.model}';
        _userAgent = 'Flutter iOS/${iosInfo.systemVersion} (${iosInfo.model})';
      }
    } catch (e) {
      print('Error getting device info: $e');
      _deviceInfo = 'Unknown Device';
      _userAgent = 'Flutter App';
    }
  }

  // Fixed phone number formatting - returns +63 format for backend
  String _formatPhoneNumber(String phoneInput) {
    // Remove any existing country code or special characters
    String cleaned = phoneInput
        .replaceAll('+63', '')
        .replaceAll('+', '')
        .replaceAll('-', '')
        .replaceAll(' ', '')
        .replaceAll('(', '')
        .replaceAll(')', '');
    
    // Handle different input formats
    if (cleaned.startsWith('0') && cleaned.length == 11) {
      // 09955578757 -> +639955578757
      return '+63${cleaned.substring(1)}';
    } else if (cleaned.length == 10 && cleaned.startsWith('9')) {
      // 9955578757 -> +639955578757
      return '+63$cleaned';
    } else if (cleaned.length == 10) {
      // Any 10-digit number -> +63 prefix
      return '+63$cleaned';
    }
    
    // If already has +63 or other format, return as is
    return phoneInput.startsWith('+') ? phoneInput : '+63$cleaned';
  }

  // Enhanced user existence check
  Future<bool> _checkUserExists(String mobileNumber) async {
    try {
      print('Checking if user exists: $mobileNumber');
      
      // URL encode the mobile number to handle the + character
      final encodedNumber = Uri.encodeComponent(mobileNumber);
      
      final response = await http.get(
        Uri.parse('$_baseUrl/users/check-mobile?mobile_number=$encodedNumber'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': _userAgent ?? 'Flutter App',
        },
      ).timeout(const Duration(seconds: 15));

      print('Check user response: ${response.statusCode}');
      print('Check user body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['exists'] ?? false;
      }
      return false;
    } on http.ClientException catch (e) {
      print('Connection error checking user: $e');
      return false;
    } catch (e) {
      print('Error checking user: $e');
      return false;
    }
  }

  // Send verification data to backend after Firebase Auth success
  Future<void> _notifyBackendOfVerification(String mobileNumber, String firebaseUid) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/firebase-phone-verified'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': _userAgent ?? 'Flutter App',
        },
        body: json.encode({
          'mobile_number': mobileNumber,
          'firebase_uid': firebaseUid,
          'device_info': _deviceInfo,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Backend notified successfully
        print('Backend notified of Firebase verification');
      } else {
        print('Backend notification failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error notifying backend: $e');
    }
  }

  // Firebase Phone Authentication with UI
  void _handleFirebasePhoneAuth(String phoneNumber) async {
    setState(() {
      _isPhoneAuthInProgress = true;
      _errorMessage = '';
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 120),
        
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            // Auto-verification completed
            UserCredential result = await FirebaseAuth.instance.signInWithCredential(credential);
            
            if (result.user != null) {
              // Notify backend
              await _notifyBackendOfVerification(phoneNumber, result.user!.uid);
              
              // Navigate to OTP screen (or home if auto-verified)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OTPVerificationScreen(
                    mobileNumber: phoneNumber,
                    purpose: AuthPurpose.login,
                  ),
                ),
              );
            }
          } catch (e) {
            print('Auto-verification error: $e');
            setState(() {
              _errorMessage = 'Auto-verification failed. Please enter code manually.';
            });
          }
        },
        
        verificationFailed: (FirebaseAuthException e) {
          print('Verification failed: ${e.code} - ${e.message}');
          setState(() {
            _isPhoneAuthInProgress = false;
            if (e.code == 'invalid-phone-number') {
              _errorMessage = 'Invalid phone number format.';
            } else if (e.code == 'too-many-requests') {
              _errorMessage = 'Too many verification attempts. Please try again later.';
            } else if (e.code == 'web-context-cancelled') {
              _errorMessage = 'Verification was cancelled. Please try again.';
            } else {
              _errorMessage = 'Phone verification failed. Please try again.';
            }
          });
        },
        
        codeSent: (String verificationId, int? resendToken) {
          print('SMS code sent successfully');
          _verificationId = verificationId;
          
          setState(() {
            _isPhoneAuthInProgress = false;
          });
          
          // Navigate to OTP verification screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationScreen(
                mobileNumber: phoneNumber,
                purpose: AuthPurpose.login,
                verificationId: verificationId, // Pass the verification ID
              ),
            ),
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification code sent successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        },
        
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      print('Firebase phone auth error: $e');
      setState(() {
        _isPhoneAuthInProgress = false;
        _errorMessage = 'Phone verification failed. Please try again.';
      });
    }
  }

  // Updated SMS handling using Firebase Auth
  void _handleSendSms() async {
    if (_formKey.currentState!.validate()) {
      String phoneInput = _phoneController.text.trim();
      
      // Format to +63 format for backend
      String formattedMobile = _formatPhoneNumber(phoneInput);
      
      print("Send SMS to: $formattedMobile (Formatted with +63)");
      print("Using Firebase Auth instead of custom backend SMS");

      // Check if user exists first
      bool userExists = await _checkUserExists(formattedMobile);
      
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

      // Use Firebase Phone Auth (handles reCAPTCHA automatically)
      _handleFirebasePhoneAuth(formattedMobile);
    }
  }

  // Enhanced Google login (placeholder for now)
  void _handleGoogleLogin() async {
  print("Google login pressed");
  
  setState(() {
    _isLoading = true;
  });

  try {
    // Initialize Google Sign In
    final GoogleSignIn googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'], // Add required scopes
    );

    // Sign out first to ensure account picker shows
    await googleSignIn.signOut();

    // Trigger the Google authentication flow
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    
    if (googleUser == null) {
      // User cancelled the sign-in
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    // Create a new credential for Firebase
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase with the Google credential
    final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    final User? user = userCredential.user;

    if (user != null) {
      // Get the Firebase ID token
      final String? firebaseIdToken = await user.getIdToken();
      
      print('Firebase User ID: ${user.uid}');
      print('User Email: ${user.email}');

      // Send ONLY the Firebase ID token to your backend
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/google-login'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': _userAgent ?? 'Flutter App',
        },
        body: json.encode({
          'firebase_id_token': firebaseIdToken,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('Google login successful: $responseData');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google login successful!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to home screen
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        final responseData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['detail'] ?? 'Google login failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } on FirebaseAuthException catch (e) {
    print('Firebase Auth error: ${e.code} - ${e.message}');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Google authentication failed. Please try again.'),
        backgroundColor: Colors.red,
      ),
    );
  } on http.ClientException catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connection error: ${e.message}'),
        backgroundColor: Colors.red,
      ),
    );
  } catch (e) {
    print('Google login error: $e');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('An unexpected error occurred during Google login.'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}
  // Email login with better error handling
  void _handleEmailLogin() async {
    print("Email login pressed");
    _showEmailLoginDialog();
  }

  // Email Login Dialog
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

  // Enhanced email login
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
          'User-Agent': _userAgent ?? 'Flutter App',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

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
        
        // TODO: Navigate to home screen
        // Navigator.pushReplacementNamed(context, '/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['detail'] ?? 'Email login failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on http.ClientException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection error: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
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
            // Background Image
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/bg.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Foreground Login Form
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 120),
                      
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

                      // Error Message Display
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

                      // Phone Number Input Field
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
                                  height: 24,
                                  color: Colors.grey,
                                  margin: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    focusNode: _mobileFocusNode,
                                    keyboardType: TextInputType.number,
                                    maxLength: 10,
                                    enabled: !_isLoading && !_isPhoneAuthInProgress,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Enter your mobile number';
                                      }
                                      if (value.length != 10) {
                                        return 'Enter exactly 10 digits';
                                      }
                                      if (!value.startsWith('9')) {
                                        return 'Mobile number should start with 9';
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

                      // Send SMS Button - now using Firebase Auth
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading || _isPhoneAuthInProgress ? null : _handleSendSms,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isLoading || _isPhoneAuthInProgress ? Colors.grey : Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          child: _isLoading || _isPhoneAuthInProgress
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _isPhoneAuthInProgress ? "Sending SMS..." : "Processing...",
                                      style: const TextStyle(fontSize: 16, color: Colors.white),
                                    ),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.sms, size: 20, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      "Send SMS",
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Security Notice - Updated for Firebase
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.verified_user, color: Colors.green.shade700, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Secured by Firebase Authentication',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Divider Text
                      const Text("or",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 16),

                      // Social Login Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Google Login
                          GestureDetector(
                            onTap: _isLoading || _isPhoneAuthInProgress ? null : _handleGoogleLogin,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: _isLoading || _isPhoneAuthInProgress ? Colors.grey : Colors.blueAccent),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Iconify(
                                Ri.google_fill,
                                size: 28,
                                color: _isLoading || _isPhoneAuthInProgress ? Colors.grey : Colors.blueAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                        ],
                      ),

                      const SizedBox(height: 50),

                      // Signup Redirect
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account yet? "),
                          GestureDetector(
                            onTap: _isLoading || _isPhoneAuthInProgress ? null : _goToSignup,
                            child: Text(
                              "Signup",
                              style: TextStyle(
                                color: _isLoading || _isPhoneAuthInProgress ? Colors.grey : Colors.deepOrange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Debug Info (remove in production)
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Debug Info:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                Text('Backend URL: $_baseUrl', style: const TextStyle(fontSize: 10)),
                                Text('Platform: ${Platform.isAndroid ? "Android" : "iOS"}', style: const TextStyle(fontSize: 10)),
                                Text('Device: $_deviceInfo', style: const TextStyle(fontSize: 10)),
                                Text('User Agent: $_userAgent', style: const TextStyle(fontSize: 10)),
                                const Text('Auth: Firebase Native', style: TextStyle(fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Loading Overlay
            if (_isLoading || _isPhoneAuthInProgress)
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