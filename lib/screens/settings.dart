import 'package:flutter/material.dart';
import '../services/session_service.dart';
import 'login.dart';
import '../utils/auth_utils.dart';
import '../services/user_deletion.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 0),
        child: Column(
          children: [
            const SizedBox(height: 40), // Status bar space
            SettingsHeader(),
            const SizedBox(height: 32),
            SettingsOptions(
              notificationsEnabled: notificationsEnabled,
              onNotificationChanged: (value) {
                setState(() {
                  notificationsEnabled = value;
                });
              },
            ),
            const SizedBox(height: 32),
            SettingsActions(),
            const SizedBox(height: 24),
            SettingsDangerZone(),
            const SizedBox(height: 60),
            SettingsFooter(),
            const SizedBox(height: 100), // Bottom navigation space
          ],
        ),
      ),
    );
  }
}

// Header Widget
class SettingsHeader extends StatelessWidget {
  const SettingsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(width: 8),
        const Text(
          'Settings',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// Settings Options Widget - Now using Rows
class SettingsOptions extends StatelessWidget {
  final bool notificationsEnabled;
  final ValueChanged<bool> onNotificationChanged;

  const SettingsOptions({
    super.key,
    required this.notificationsEnabled,
    required this.onNotificationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSettingsRow(
          title: 'Notifications',
          trailing: Switch(
            value: notificationsEnabled,
            onChanged: onNotificationChanged,
            activeColor: Colors.blue,
          ),
        ),
        const SizedBox(height: 8),
        _buildSettingsRow(
          title: 'Help Center',
          onTap: () {
            showHelpRequestModal(context);
          },
        ),
        _buildSettingsRow(
          title: 'Send Feedback',
          onTap: () {
            showFeedbackModal(context);
          },
        ),
        _buildSettingsRow(
          title: 'Terms of Service',
          onTap: () {
            // Navigate to terms
          },
        ),
      ],
    );
  }

  Widget _buildSettingsRow({
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              trailing ??
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Method to show help request form modal
  void showHelpRequestModal(BuildContext context) {
    final TextEditingController helpController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Help Center',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(
                        Icons.close,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Submit a request section
                const Text(
                  'Submit a request',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'How can we help?',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),

                const SizedBox(height: 16),

                // Help request text area
                TextField(
                  controller: helpController,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText:
                        'What is your query about?\n\n\n\nCan you give us more details?',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      height: 1.5,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),

                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (helpController.text.trim().isNotEmpty) {
                        // Handle help request submission
                        await submitHelpRequest(helpController.text);

                        // Close help request modal
                        Navigator.of(context).pop();

                        // Show success modal
                        showHelpRequestSubmittedModal(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5722),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Submit',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Method to show help request submitted modal
  void showHelpRequestSubmittedModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.close,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Help request illustration
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Image.asset(
                    'assets/images/help_request_submitted.png', // Replace with your actual asset path
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 24),

                // Success message
                const Text(
                  'Help Request\nSubmitted!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 16),

                // Description
                Text(
                  'Your help request has been submitted. We\'ll get back to you soon!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 24),

                // OK Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE3F2FD),
                      foregroundColor: Colors.blue,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Placeholder function for help request submission
  Future<void> submitHelpRequest(String helpText) async {
    // Add your actual help request submission logic here
    // For example: API call to submit help request
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // Method to show feedback form modal
  void showFeedbackModal(BuildContext context) {
    final TextEditingController feedbackController = TextEditingController();
    int selectedRating = 0;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with close button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Send Feedback',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Icon(
                            Icons.close,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Rating section
                    const Text(
                      'Rate EmotiCoach',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Share your feedback with the developers to help improve EmotiCoach',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Star rating
                    Row(
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedRating = index + 1;
                            });
                          },
                          child: Icon(
                            Icons.star,
                            size: 32,
                            color: index < selectedRating
                                ? Colors.amber
                                : Colors.grey[300],
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 24),

                    // Feedback text area
                    TextField(
                      controller: feedbackController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText:
                            'Only the stars, feedback, and app info will be shared.',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.blue),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selectedRating > 0
                            ? () async {
                                // Handle feedback submission
                                await submitFeedback(
                                  selectedRating,
                                  feedbackController.text,
                                );

                                // Close feedback modal
                                Navigator.of(context).pop();

                                // Show success modal
                                showFeedbackSubmittedModal(context);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedRating > 0
                              ? const Color(0xFFFF5722)
                              : Colors.grey[300],
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Submit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Placeholder function for feedback submission
  Future<void> submitFeedback(int rating, String feedback) async {
    // Add your actual feedback submission logic here
    // For example: API call to submit feedback
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // Method to show feedback submitted modal
  void showFeedbackSubmittedModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.close,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Feedback illustration
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Image.asset(
                    'assets/images/feedback_submitted.png', // Replace with your actual asset path
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 24),

                // Success message
                const Text(
                  'Feedback Submitted!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 16),

                // Description
                Text(
                  'Thank you for your feedback! We appreciate your input.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 24),

                // OK Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE3F2FD),
                      foregroundColor: Colors.blue,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Settings Actions Widget (Download Data, Logout)
class SettingsActions extends StatelessWidget {
  const SettingsActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Download my Data button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // Handle data download
              showDataDownloadedModal(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE3F2FD),
              foregroundColor: Colors.blue,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Download my Data',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Logout button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              await SimpleSessionService.clearSession();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFEBEE),
              foregroundColor: Colors.red,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }

  void showDataDownloadedModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.close,
                        color: Color.fromARGB(255, 0, 0, 0),
                        size: 20,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Illustration placeholder
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Image.asset(
                    'assets/images/download.png', // Replace with your actual asset path
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 24),

                // Success message
                const Text(
                  'Data Downloaded!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 24),

                // OK Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD55E42),
                      foregroundColor: const Color.fromARGB(255, 255, 255, 255),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Danger Zone Widget - Now using Row
class SettingsDangerZone extends StatelessWidget {
  const SettingsDangerZone({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Handle delete account
        _showDeleteConfirmationDialog(context);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Delete Account',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Illustration
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Image.asset(
                    'assets/images/delete.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),

                // Question text
                const Text(
                  'Are you sure you want to delete\nyour account?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 32),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          backgroundColor: Color(0xFFFFFFFF),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'NO',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () async{
                          Navigator.of(context).pop(); // close dialog first
                            try {
                              // 1. Get current userId
                              final userId = await AuthUtils.getSafeUserId();

                              if (userId != null) {
                                // 2. Call your delete account API
                                await UserService().deleteAccount(userId);

                                // 3. Show confirmation
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Your account has been deleted successfully.'),
                                    backgroundColor: Colors.green,
                                  ),
                                );

                                // 4. Redirect to login or welcome screen
                                Navigator.pushReplacementNamed(context, '/login');
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('User ID not found.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to delete account: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Color(
                            0xFFD55E42,
                          ), // Light red/coral color
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'YES',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Settings Footer Widget - Fixed spacing implementation
class SettingsFooter extends StatelessWidget {
  const SettingsFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 130, bottom: 0),
      child: const Center(
        child: Text(
          'Version 1.0.0',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
            shadows: [
              Shadow(
                color: Colors.black26,
                offset: Offset(0, 7),
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
