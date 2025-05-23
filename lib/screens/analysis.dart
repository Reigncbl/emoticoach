import 'package:flutter/material.dart';
import '../utils/colors.dart';

class EmotionAnalysisCard extends StatelessWidget {
  final String emotion;
  final int percent;
  final String description;
  final bool highlighted;

  const EmotionAnalysisCard({
    super.key,
    required this.emotion,
    required this.percent,
    required this.description,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFD6EEFF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted ? const Color(0xFF7EC3FF) : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                emotion,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: highlighted ? const Color(0xFF2477B0) : Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: highlighted
                      ? const Color(0xFFBCE1FF)
                      : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: highlighted
                        ? const Color(0xFF2477B0)
                        : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class EmotionTag extends StatelessWidget {
  final String text;

  const EmotionTag({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE3B3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: Color(0xFF7A4F00)),
      ),
    );
  }
}
