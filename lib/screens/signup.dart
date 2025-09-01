import 'package:flutter/material.dart';
import 'login.dart';
import '../utils/colors.dart';
import 'otp_verification.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/ri.dart'; // Remix Icons
import 'package:iconify_flutter/icons/ic.dart'; // Material Icons

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  // createState() creates the mutable state for this widget
  @override
  State<SignupScreen> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignupScreen> {
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

  // Function for "Send SMS" button
  void _sendSMS() {
    if (_formKey.currentState!.validate()) {
      String firstName = _firstNameController.text;
      String lastName = _lastNameController.text;
      String mobile = _mobileController.text;

      print('First Name: $firstName');
      print('Last Name: $lastName');
      print('Mobile: +63$mobile');

      // Navigate to OTP screen and pass signup data + purpose
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OTPVerificationScreen(
            firstName: firstName,
            lastName: lastName,
            mobileNumber: '+63$mobile',
            purpose: AuthPurpose.signup,
          ),
        ),
      );
    }
  }

  // Function for Google Sign In
  void _signInWithGoogle() {
    // GOOGLE SIGN-IN LOGIC HERE
    print('Google sign-in');
  }

  // Function for Email Sign In
  void _signInWithEmail() {
    // EMAIL SIGN-IN LOGIC HERE
    print('Email sign-in');
  }

  // Function to go back to login
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
            // === Background Image ===
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/bg.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Main COntent
            SafeArea(
              // Padding adds space around our content so it doesn't touch the screen edges
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                ), // 24 pixels left and right
                // Form widget wraps all our input fields for validation
                child: Form(
                  key: _formKey, // Connect our form key to this form
                  // Column arranges widgets vertically (top to bottom)
                  child: Column(
                    // crossAxisAlignment makes all children stretch to fill the width
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // SizedBox creates empty space (like a spacer)
                      const SizedBox(height: 60),

                      // === TITLE SECTION ===
                      const Text(
                        'Register',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: kBlack,
                        ),
                        textAlign:
                            TextAlign.center, // Center the text horizontally
                      ),

                      const SizedBox(height: 50), // Space below title
                      // === FIRST NAME SECTION ===
                      const Text(
                        'First Name',
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(
                        height: 8,
                      ), // Small space between label and input
                      // First name input field
                      TextFormField(
                        controller:
                            _firstNameController, // Connect to our controller
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          enabledBorder: OutlineInputBorder(
                            // When field is not focused
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: OutlineInputBorder(
                            // When field is focused (user tapped it)
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: kBrightBlue),
                          ),
                          // Padding inside the input field
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, // 16 pixels left and right
                            vertical: 16, // 16 pixels top and bottom
                          ),
                        ),
                        // validator checks if the input is valid
                        validator: (value) {
                          // If the field is empty, return an error message
                          if (value == null || value.isEmpty) {
                            return 'Please enter your first name';
                          }
                          // If validation passes, return null (no error)
                          return null;
                        },
                      ),

                      const SizedBox(height: 20), // Space between fields
                      // LAST NAME SECTION
                      const Text(
                        'Last Name',
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _lastNameController,
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
                            width: _isMobileFocused ? 1.0 : 1.0,
                          ),
                          borderRadius: BorderRadius.circular(8.0),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: const Center(child: Text('+63')),
                            ),
                            Container(
                              width: 1,
                              height:
                                  28, // Centered divider - half the container height
                              color: Colors.grey, // Keep divider grey always
                              margin: const EdgeInsets.symmetric(
                                vertical: 14,
                              ), // Centers the divider vertically
                            ),
                            Expanded(
                              child: TextFormField(
                                controller: _mobileController,
                                focusNode: _mobileFocusNode,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your mobile number';
                                  }
                                  // Check if the phone number is exactly 10 digits long
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

                      const SizedBox(height: 40), // Space before the button
                      // SEND SMS BUTTON
                      ElevatedButton(
                        onPressed: _sendSMS,
                        // Btn style
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBrightBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),

                        // Button text
                        child: const Text(
                          'Send SMS',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700, // Semi-bold text
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
                            onTap: _signInWithGoogle,
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
                            onTap: _signInWithEmail,
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

                      // Spacer pushes everything above it to the top and everything below to the bottom
                      const Spacer(),

                      // LOGIN LINK AT THE BOTTOM
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Regular text
                          const Text(
                            'Already have an account? ',
                            style: TextStyle(fontSize: 16, color: kBlack),
                          ),

                          // Tappable login link
                          GestureDetector(
                            onTap: _navigateToLogin,
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

                      const SizedBox(height: 30), // Space at the bottom
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
