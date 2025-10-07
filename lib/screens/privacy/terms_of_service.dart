import 'package:flutter/material.dart';
import '../../utils/colors.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          "Terms of Service",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: kBlack,
          ),
        ),
        iconTheme: const IconThemeData(color: kBlack),
      ),
      body: Container(
        color: Colors.white,
        child: DefaultTextStyle(
          style: const TextStyle(fontSize: 16, color: Colors.black),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionTitle("1. Acceptance of Terms"),
                const Text(
                  "By accessing and using EmotiCoach, you accept and agree to be bound by the terms and provisions of this agreement. If you do not agree to abide by the above, please do not use this service.",
                ),
                const SizedBox(height: 16),

                sectionTitle("2. Use License"),
                bullet(2, 1, "Permission is granted to use EmotiCoach for personal, non-commercial purposes."),
                bullet(2, 2, "This is the grant of a license, not a transfer of title, and under this license you may not:"),
                const Padding(
                  padding: EdgeInsets.only(left: 24, top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("• Modify or copy the materials"),
                      Text("• Use the materials for any commercial purpose"),
                      Text("• Attempt to decompile or reverse engineer any software contained in EmotiCoach"),
                      Text("• Remove any copyright or other proprietary notations from the materials"),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                sectionTitle("3. Service Description"),
                bullet(3, 1, "EmotiCoach provides social communication improvement tools and companionship features."),
                bullet(3, 2, "The service includes AI-powered conversation analysis and suggestions."),
                bullet(3, 3, "Features may be updated, modified, or discontinued at any time without prior notice."),
                const SizedBox(height: 16),

                sectionTitle("4. User Responsibilities"),
                bullet(4, 1, "You are responsible for maintaining the confidentiality of your account credentials."),
                bullet(4, 2, "You agree to use the service in compliance with all applicable laws and regulations."),
                bullet(4, 3, "You will not use the service for any unlawful or prohibited purpose."),
                bullet(4, 4, "You will not attempt to gain unauthorized access to any portion of the service."),
                const SizedBox(height: 16),

                sectionTitle("5. Privacy and Data Collection"),
                bullet(5, 1, "Your use of EmotiCoach is also governed by our Privacy Policy."),
                bullet(5, 2, "We collect and process data as described in our Privacy Policy."),
                bullet(5, 3, "You consent to the collection and use of information as outlined in our Privacy Policy."),
                const SizedBox(height: 16),

                sectionTitle("6. Third-Party Services"),
                bullet(6, 1, "EmotiCoach integrates with third-party services, including but not limited to Telegram."),
                bullet(6, 2, "Your use of third-party services is subject to their respective terms and conditions."),
                bullet(6, 3, "We are not responsible for the practices or policies of third-party services."),
                const SizedBox(height: 16),

                sectionTitle("7. Intellectual Property"),
                bullet(7, 1, "All content, features, and functionality are owned by EmotiCoach and protected by intellectual property laws."),
                bullet(7, 2, "You may not reproduce, distribute, or create derivative works without express permission."),
                const SizedBox(height: 16),

                sectionTitle("8. Disclaimer of Warranties"),
                const Text(
                  "EmotiCoach is provided 'as is' and 'as available' without any warranties of any kind, either express or implied. We do not warrant that the service will be uninterrupted, timely, secure, or error-free.",
                ),
                const SizedBox(height: 16),

                sectionTitle("9. Limitation of Liability"),
                const Text(
                  "In no event shall EmotiCoach or its suppliers be liable for any damages (including, without limitation, damages for loss of data or profit, or due to business interruption) arising out of the use or inability to use EmotiCoach.",
                ),
                const SizedBox(height: 16),

                sectionTitle("10. Medical Disclaimer"),
                const Text(
                  "EmotiCoach is not a healthcare or medical service provider. The service should not be used as a substitute for professional medical advice, diagnosis, or treatment. Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition.",
                ),
                const SizedBox(height: 16),

                sectionTitle("11. Account Termination"),
                bullet(11, 1, "We reserve the right to terminate or suspend your account at any time without prior notice."),
                bullet(11, 2, "You may terminate your account at any time through the app settings."),
                bullet(11, 3, "Upon termination, your right to use the service will immediately cease."),
                const SizedBox(height: 16),

                sectionTitle("12. Modifications to Terms"),
                const Text(
                  "We reserve the right to modify these Terms of Service at any time. Changes will be effective immediately upon posting. Your continued use of the service after changes are posted constitutes acceptance of the modified terms.",
                ),
                const SizedBox(height: 16),

                sectionTitle("13. Governing Law"),
                const Text(
                  "These Terms shall be governed by and construed in accordance with applicable laws, without regard to its conflict of law provisions.",
                ),
                const SizedBox(height: 16),

                sectionTitle("14. Contact Information"),
                const Text(
                  "If you have any questions about these Terms of Service, please contact us through the Help Center in the app.",
                ),
                const SizedBox(height: 32),

                const Text(
                  "Last updated: October 8, 2025",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
    );
  }

  Widget bullet(int section, int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$section.$number ", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }
}
