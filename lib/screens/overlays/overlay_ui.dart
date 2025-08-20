import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'overlay_edit.dart';

class OverlayUI extends StatefulWidget {
  const OverlayUI({super.key});

  @override
  State<OverlayUI> createState() => _OverlayUIState();
}

class _OverlayUIState extends State<OverlayUI> {
  BoxShape _currentShape = BoxShape.circle; // Start with circle
  bool _showEditScreen = false; // Add this state variable
  SendPort? homePort;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: _showEditScreen
          ? EditOverlayScreen(
              initialText: 'Okay po. Ingat po palagi.',
              onBack: _goBackToMainScreen,
            )
          : (_currentShape == BoxShape.circle
                ? _buildCircleView()
                : _buildRectangleView()),
    );
  }

  // Add this method to handle going back to main screen
  void _goBackToMainScreen() async {
    await FlutterOverlayWindow.resizeOverlay(400, 500, false);
    setState(() {
      _showEditScreen = false;
    });
  }

  // Add this method to handle going to edit screen
  void _goToEditScreen() async {
    await FlutterOverlayWindow.resizeOverlay(400, 500, false);
    setState(() {
      _showEditScreen = true;
    });
  }

  Widget _buildCircleView() {
    return GestureDetector(
      onTap: () async {
        await FlutterOverlayWindow.resizeOverlay(400, 500, false);
        setState(() {
          _currentShape = BoxShape.rectangle;
        });
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
        child: Center(
          child: SizedBox(
            height: 100,
            width: 100,
            child: Icon(
              Icons.chat_bubble_outline,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRectangleView() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        width: MediaQuery.of(context).size.width - 32.0,
        height: 500,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.face, color: Colors.blue, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Message from Carlo Lorieta:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      await FlutterOverlayWindow.resizeOverlay(100, 100, true);
                      setState(() {
                        _currentShape = BoxShape.circle;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // CONTENT AREA
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // MESSAGE BUBBLE
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Text(
                        '"Let\'s just skip the technical details and move on, hahahahaha!"',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // TONE SECTION
                    _buildSection(
                      icon: '🔍',
                      title: 'Detected Tone',
                      content: 'Casual & Playful',
                    ),
                    const SizedBox(height: 10),

                    // INTERPRETATION SECTION
                    _buildSection(
                      icon: '📝',
                      title: 'Interpretation',
                      content:
                          'Carlo seems to be keeping the mood light and understanding. '
                          'He\'s probably saying it\'s okay to drop the topic.',
                    ),
                    const SizedBox(height: 10),

                    // SUGGESTED RESPONSE SECTION
                    const Text(
                      '💡 Suggested Response',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green.shade300),
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Thank you po for understanding! Wishing you and the team all the best din 🫶',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildActionButton(
                                icon: Icons.check_circle_outline,
                                label: 'Use',
                                color: Colors.green,
                                onTap: () {
                                  // Handle use action
                                },
                              ),
                              _buildActionButton(
                                icon: Icons.edit,
                                label: 'Edit',
                                color: Colors.blue,
                                onTap: _goToEditScreen,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // CHECKLIST
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Text(
                        '✓ Keeps things friendly\n'
                        '✓ Acknowledges his tone\n'
                        '✓ Closes the convo on a good note',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String icon,
    required String title,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$icon $title',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          content,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 12,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
