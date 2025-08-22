import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class EditOverlayScreen extends StatefulWidget {
  final String initialText;
  final VoidCallback onBack;

  const EditOverlayScreen({
    super.key,
    required this.initialText,
    required this.onBack,
  });

  @override
  State<EditOverlayScreen> createState() => _EditOverlayScreenState();
}

class _EditOverlayScreenState extends State<EditOverlayScreen> {
  late TextEditingController _textController;
  double _formality = 0.42; // 42% as shown in image
  double _assertiveness = 0.22; // 22% as shown in image
  double _warmth = 0.70; // 70% as shown in image

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _resetToDefaults() {
    setState(() {
      _formality = 0.42;
      _assertiveness = 0.22;
      _warmth = 0.70;
      _textController.text = widget.initialText;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          width: MediaQuery.of(context).size.width - 32.0,
          height: 450,
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
                    GestureDetector(
                      onTap: widget.onBack,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '✏️ Craft my Own Reply',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // CONTENT
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // YOUR RESPONSE SECTION
                      Text(
                        'Your Response',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // TEXT INPUT
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: _textController,
                          maxLines: null,
                          expands: true,
                          style: TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(8),
                            hintText: 'Type your response...',
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ACTION BUTTONS
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              label: '🔍 Analyze',
                              color: Colors.blue,
                              onTap: () {
                                // Handle analyze action
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildActionButton(
                              label: '✅ Apply Changes',
                              color: Colors.green,
                              onTap: () {
                                // Handle apply changes
                                widget.onBack();
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // TONE CONTROLS
                      Column(
                        children: [
                          _buildSlider(
                            label: 'Formality',
                            value: _formality,
                            leftLabel: 'Casual',
                            rightLabel: 'Formal',
                            onChanged: (value) =>
                                setState(() => _formality = value),
                          ),
                          const SizedBox(height: 4),
                          _buildSlider(
                            label: 'Assertiveness',
                            value: _assertiveness,
                            leftLabel: 'Passive',
                            rightLabel: 'Assertive',
                            onChanged: (value) =>
                                setState(() => _assertiveness = value),
                          ),
                          const SizedBox(height: 4),
                          _buildSlider(
                            label: 'Warmth',
                            value: _warmth,
                            leftLabel: 'Professional',
                            rightLabel: 'Friendly',
                            onChanged: (value) =>
                                setState(() => _warmth = value),
                          ),
                          const SizedBox(height: 4),

                          // RESET BUTTON
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: _resetToDefaults,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.refresh,
                                      color: Colors.grey.shade600,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Reset',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required String leftLabel,
    required String rightLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),

        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.blue,
            inactiveColor: Colors.grey.shade300,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              leftLabel,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
            Text(
              rightLabel,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
  }
}
