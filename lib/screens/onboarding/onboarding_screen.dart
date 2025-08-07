import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'onboard_page.dart'; // Reusable page widget
import '../privacy/data_privacy.dart';
import '../../utils/colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  bool isLastPage = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void goToNextScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DataPrivacyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // PageView for onboarding pages
          PageView(
            controller: _controller,
            onPageChanged: (index) {
              setState(() {
                isLastPage = index == 3;
              });
            },
            children: const [
              OnboardPage(
                title: "Welcome!",
                description: "EmotiCoach is an innovative chat-app meant to help those in need of improving their social game!",
                imagePath: "assets/images/onb_welcome.png",
              ),
              OnboardPage(
                title: "Chat Assistant Overlay",
                description: "Need a hand? Our Chat Assistant pops up right where you are to provide insights and response suggestions.",
                imagePath: "assets/images/onb_chat_assistant_overlay.png",
              ),
              OnboardPage(
                title: "Reading Modules",
                description: "Take your time and dive in! These bite-sized learning modules helps you absorb key topics at your own pace.",
                imagePath: "assets/images/onb_reading_modules.png",
              ),
              OnboardPage(
                title: "Chat Learning Scenarios",
                description: "Learn by doing! These interactive chat scenarios put you in realistic situations so you can practice, explore, and make choices in a safe and fun way.",
                imagePath: "assets/images/onb_chat_learning_scenarios.png",
              ),
            ],
          ),

          // Skip button
          Positioned(
            top: 50,
            right: 20,
            child: TextButton(
              onPressed: goToNextScreen,
              child: const Text(
                "Skip",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: kDarkBlue,
                  ),
                ),
            ),
          ),

          // Dot indicator
          Positioned(
            bottom: 130,
            left: 0,
            right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: _controller,
                count: 4,
                effect: const WormEffect(
                  dotHeight: 10,
                  dotWidth: 10,
                  activeDotColor: kDarkBlue,
                ),
              ),
            ),
          ),

          // Next or Get Started button (centered)
          Positioned(
            bottom: 45,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDarkOrange,
                  foregroundColor: kWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 91, vertical: 15),
                ),
                onPressed: () {
                  if (isLastPage) {
                    goToNextScreen();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Text(
                  isLastPage ? "Get Started" : "Next",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}