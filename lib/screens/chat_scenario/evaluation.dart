import 'package:flutter/material.dart';
import '../../utils/colors.dart';

// NOTE: Wala pa yung score, overall feedback, button functions

void showEvaluationOverlay(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // makes it full-screen height if needed
    backgroundColor: Colors.transparent, // transparent corners
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6, // starting height (60% of screen)
        minChildSize: 0.4,     // minimum height
        maxChildSize: 0.95,    // maximum height
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: const [
                      Text(
                        'Evaluation',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Ratings',
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),
                // Buttons section at bottom
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Return to scenarios - no function yet
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Return to Scenarios'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Replay the scenario - no function yet
                            Navigator.of(context).pop(); // Close overlay
                            // NOTE: Wala pa yung reset convo
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Replay'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}