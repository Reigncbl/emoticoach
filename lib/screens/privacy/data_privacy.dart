import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../signup.dart';

class DataPrivacyScreen extends StatefulWidget {
  const DataPrivacyScreen({super.key});

  @override
  State<DataPrivacyScreen> createState() => _DataPrivacyScreenState();
}

class _DataPrivacyScreenState extends State<DataPrivacyScreen> {
  bool _isAgreed = false;
  bool _hasScrolledToEnd = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
      if (!_hasScrolledToEnd) {
        setState(() {
          _hasScrolledToEnd = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Terms & Condition",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: kBlack,
          ),
        ),
        iconTheme: const IconThemeData(color: kBlack),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.white,
              child: DefaultTextStyle(
                style: const TextStyle(fontSize: 20, color: Colors.black),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    sectionTitle("1. Medical Disclaimer"),
                    bullet(1, 1, "EmotiCoach is designed to improve social communication and give companionship to its users. However, we are not a healthcare or medical service provider, nor should our services be considered medical care."),
                    const SizedBox(height: 16),

                    sectionTitle("2. Privacy & Security"),
                    bullet(2, 1, "The app will store or transmit any personal or sensitive user data to external servers for better quality service, unless not enabled by the user."),
                    bullet(2, 2, "All data related to message analysis and emotional embeddings shall be stored in external servers, unless not allowed by the user."),
                    bullet(2, 3, "Access to the app must require basic local authentication (e.g. password, optional biometrics)."),
                    bullet(2, 4, "Only authorized modules are permitted to access Telegram messages via the Telethon API."),
                    const SizedBox(height: 16),

                    sectionTitle("3. User Permission Policy"),
                    bullet(3, 1, "Users can access only their own data and Telegram sessions."),
                    bullet(3, 2, "The app only supports single-user access. Every user has the same level of permission and functionality. There are no built-in roles such as admin, moderator, or guest."),
                    const SizedBox(height: 16),

                    sectionTitle("4. AI Interaction Procedure"),
                    bullet(4, 1, "When the user activates the overlay, the app fetches the most recent Telegram message using the Telethon API and analyzes it based on the whole conversation’s context and data."),
                    const SizedBox(height: 16),

                    sectionTitle("5. Third Party Platform Policy (Telegram)"),
                    const Text("The app connects to Telegram through the Telethon API to enable message analysis and overlay functionality. All interactions with Telegram are subject to Telegram’s own Terms of Service and Privacy Policy. EmotiCoach’s system shall comply to these third-party policies, particularly:"),
                    bullet(5, 1, "Message access and handling through authorized sessions only."),
                    bullet(5, 2, "No violating Telegram’s usage restrictions or interfering with its basic functionalities. This includes but is not limited to implementing a ‘ghost mode’ and making actions on behalf of the user without their knowledge."),
                    const SizedBox(height: 16),

                    sectionTitle("6. Changes to This Policy"),
                    const Text(
                      "We may update this Terms & Conditions periodically. Changes will be notified through the app or email.",
                    ),

                    const SizedBox(height: 100), // space above the buttons
                    ],
                  ),
                ),
              ),
            ),
          ),

          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 5.0),
            child: Row(
              children: [
                Checkbox(
                  value: _isAgreed,
                  activeColor: kBrightBlue,
                  onChanged: _hasScrolledToEnd ? (bool? value) {
                    setState(() {
                      _isAgreed = value ?? false;
                    });
                  } : null,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _hasScrolledToEnd ? () {
                      setState(() {
                        _isAgreed = !_isAgreed;
                      });
                    } : null,
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 16, 
                          color: _hasScrolledToEnd ? kBlack : kDarkGrey,
                        ),
                        children: [
                          const TextSpan(
                            text: "I agree to the guidelines of EmotiCoach ",),
                          TextSpan(
                            text: "Terms & Conditions",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _hasScrolledToEnd ? kBlack : kDarkGrey,
                            ),
                          ),
                          const TextSpan(text: "."),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.white,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kDarkGrey,
                      side: BorderSide(color: kDarkGrey),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isAgreed ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SignupScreen()),
                      );
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBrightBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                        "Continue",
                        style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // The 1. 2. 3.
  Widget sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
    );
  }

  // The 1.1 2.1 3.1
  Widget bullet(int section, int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$section.$number ", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }
}