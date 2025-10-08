import 'package:flutter/material.dart';

class OverlayTutorialModal extends StatefulWidget {
  final VoidCallback onClose;
  const OverlayTutorialModal({super.key, required this.onClose});

  @override
  State<OverlayTutorialModal> createState() => _OverlayTutorialModalState();
}

class _OverlayTutorialModalState extends State<OverlayTutorialModal> {
  int _step = 0;

  // Replace with your actual assets/icons
  final List<Widget> _icons = [
    Icon(Icons.toggle_on, color: Colors.blue, size: 64),
    Icon(Icons.send, color: Colors.blue, size: 64),
    Icon(Icons.face, color: Colors.blue, size: 64),
    Icon(Icons.remove_red_eye, color: Colors.blue, size: 64),
    Icon(Icons.arrow_forward, color: Colors.blue, size: 64),
  ];

  final List<String> _titles = List.filled(5, "How to Use Overlay");
  final List<String> _mainTexts = [
    "1. Enable overlay and toggle ON in app",
    "2. Open messaging app",
    "3. Tap widget",
    "4. View message analysis and suggested responses",
    "5. Tap to paste the suggested response",
  ];
  final List<String> _subTexts = [
    "",
    "Widget appears automatically",
    "when you get a message",
    "Adjust tone if needed",
    "into your chat",
  ];

  void _next() {
    if (_step < 4) setState(() => _step++);
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: Center(
        child: Container(
          width: 320,
          height: 380,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Skip button
                      Align(
                        alignment: Alignment.topRight,
                        child: GestureDetector(
                          onTap: widget.onClose,
                          child: Text(
                            "SKIP",
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      // Title
                      Text(
                        _titles[_step],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 22),
                      // Icon
                      _icons[_step],
                      SizedBox(height: 22),
                      // Main
                      Text(
                        _mainTexts[_step],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_subTexts[_step].isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _subTexts[_step],
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      SizedBox(height: 22),
                      // Step indicators
                    ],
                  ),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(22),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _step
                                ? Colors.deepOrange
                                : Colors.grey[300],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (_step > 0) ...[
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _back,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  elevation: 0,
                                ),
                                child: const Text("BACK"),
                              ),
                            ),
                          ),
                        ] else
                          const Spacer(),

                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _step == 4 ? widget.onClose : _next,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.zero,
                                    bottomLeft: Radius.zero,
                                    bottomRight: Radius.circular(22),
                                  ),
                                ),
                              ),
                              child: Text(_step == 4 ? "GOT IT" : "NEXT"),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
