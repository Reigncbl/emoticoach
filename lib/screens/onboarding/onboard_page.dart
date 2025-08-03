import 'package:flutter/material.dart';
import '../../utils/colors.dart';

class OnboardPage extends StatelessWidget {
  final String title;
  final String description;
  final String imagePath;

  const OnboardPage({
    required this.title,
    required this.description,
    required this.imagePath,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imagePath,
            height: 250,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: kDarkOrange,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(
              fontSize: 16,
              color: kBlack,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
