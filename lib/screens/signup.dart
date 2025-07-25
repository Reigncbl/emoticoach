import 'package:flutter/material.dart';
import '../utils/colors.dart';
import 'login.dart';
import 'otp_verification.dart';
import 'package:iconify_flutter/iconify_flutter.dart';
import 'package:iconify_flutter/icons/ri.dart';   // Remix Icons
import 'package:iconify_flutter/icons/ic.dart';   // Material Icons


class SignupScreen extends StatefulWidget {
  // Constructor - this is called when creating a new instance of SignupScreen
  const SignupScreen({Key? key}) : super(key: key);

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

  // dispose() is called when this page is removed from memory
  // We need to clean up our controllers to prevent memory leaks
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
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
            purpose: AuthPurpose.signup, // ✅ This line fixes the error
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
      // SafeArea ensures our content doesn't go behind the status bar or notch
      body: Stack (
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
      // Main COntent
      SafeArea(
        // Padding adds space around our content so it doesn't touch the screen edges
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0), // 24 pixels left and right
          
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
                
                // TITLE SECTION
                const Text(
                  'Register',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center, // Center the text horizontally
                ),
                
                const SizedBox(height: 50), // Space below title
                
                // FIRST NAME SECTION
                // Label for the first name field
                const Text(
                  'First Name',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87, // Slightly lighter than pure black
                  ),
                ),
                const SizedBox(height: 8), // Small space between label and input
                
                // First name input field
                TextFormField(
                  controller: _firstNameController, // Connect to our controller
                  
                  // decoration controls how the input field looks
                  decoration: InputDecoration(
                    // Different border styles for different states
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8), // Rounded corners
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    enabledBorder: OutlineInputBorder( // When field is not focused
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder( // When field is focused (user tapped it)
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                    // Padding inside the input field
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, // 16 pixels left and right
                      vertical: 16,   // 16 pixels top and bottom
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
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
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
                      borderSide: const BorderSide(color: Colors.blue),
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
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone, // Show phone keyboard when user taps
                  decoration: InputDecoration(
                    prefixText: '+63 ',
                    prefixStyle: const TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                    ),
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
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your mobile number';
                    }
                    // Check if the phone number is at least 10 digits long
                    if (value.length < 10) {
                      return 'Please enter a valid mobile number';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 40), // Space before the button
                
                // SEND SMS BUTTON
                ElevatedButton(
                  onPressed: _sendSMS,
                  // Btn style
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,  
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
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Iconify(
                            Ri.google_fill,
                            size: 28,
                            color: Colors.blue,
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
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Iconify(
                            Ic.baseline_email,
                            size: 28,
                            color: Colors.blue,
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
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    
                    // Tappable login link
                    GestureDetector(
                      onTap: _navigateToLogin,
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.orange,
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
    );
  }
}