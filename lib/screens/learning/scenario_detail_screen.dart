import 'package:flutter/material.dart';
import '../../models/scenario_models.dart';
import '../../utils/colors.dart';
import '../../services/scenario_service.dart';
import 'scenario.dart';

class ScenarioDetailScreen extends StatefulWidget {
  final Scenario scenario;

  const ScenarioDetailScreen({super.key, required this.scenario});

  @override
  State<ScenarioDetailScreen> createState() => _ScenarioDetailScreenState();
}

class _ScenarioDetailScreenState extends State<ScenarioDetailScreen> {
  int _currentRating = 0;

  @override
  Widget build(BuildContext context) {
    final hasScenarioRatings = widget.scenario.hasRatings;
    final ratingValue = hasScenarioRatings
        ? '${widget.scenario.averageRating!.toStringAsFixed(1)}★'
        : 'New';
    final ratingLabel = hasScenarioRatings
        ? 'Rating (${widget.scenario.ratingCount})'
        : 'Rating';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Gradient Header with Stats Inside
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF9A56), Color(0xFFD55E42)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        "Scenario",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.scenario.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "AI Persona: ${_getPersonaFromCategory(widget.scenario.category)}",
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _capitalizeFirst(widget.scenario.difficulty),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stat boxes now inside gradient
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatCard(
                        value: "25", // Default XP points for scenarios
                        label: "XP Points",
                        color: Colors.white.withOpacity(0.15),
                        textColor: Colors.white,
                      ),
                      _buildStatCard(
                        value: ratingValue,
                        label: ratingLabel,
                        color: Colors.white.withOpacity(0.15),
                        textColor: Colors.white,
                      ),
                      _buildStatCard(
                        value: _formatDuration(
                          widget.scenario.estimatedDuration,
                        ),
                        label: "Minutes",
                        color: Colors.white.withOpacity(0.15),
                        textColor: Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Synopsis Section
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.scenario.description,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),

                  
                    
                    // Skills You'll Learn Section
                    const Text(
                      'Skills You\'ll Practice',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: _getSkillsFromCategory(widget.scenario.category)
                          .map(
                            (skill) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildSkillChip(skill),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(
                      height: 40,
                    ), // Extra space before the bottom button
                  ],
                ),
              ),
            ),

            // Fixed button at bottom
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _startScenario(context),
                      icon: const Icon(Icons.chat, size: 20),
                      label: const Text(
                        'Start Scenario',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFD55E42),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startScenario(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final result = await ScenarioService.startScenario(widget.scenario.id);

      // Close loading indicator
      if (context.mounted) Navigator.pop(context);

      if (result['success'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScenarioScreen(
              scenarioId: widget.scenario.id,
              scenarioTitle: widget.scenario.title,
              aiPersona:
                  result['character_name'] ??
                  _getPersonaFromCategory(widget.scenario.category),
              initialMessage:
                  result['first_message'] ?? 'Loading conversation...',
            ),
          ),
        );
      } else {
        _showErrorSnackBar(
          context,
          'Failed to start scenario: ${result['error'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      // Close loading indicator if still open
      if (context.mounted) Navigator.pop(context);
      _showErrorSnackBar(context, 'Failed to start scenario: $e');
    }
  }

  void _submitRating(int rating) {
    // TODO: Implement actual rating submission to backend
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'You rated this scenario $rating star${rating != 1 ? 's' : ''}!',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getPersonaFromCategory(String category) {
    switch (category.toLowerCase()) {
      case 'workplace':
      case 'professional':
        return 'Manager';
      case 'friendship':
        return 'Friend';
      case 'family':
        return 'Family Member';
      case 'social':
        return 'Classmate';
      default:
        return 'AI Assistant';
    }
  }

  List<String> _getSkillsFromCategory(String category) {
    switch (category.toLowerCase()) {
      case 'workplace':
      case 'professional':
        return [
          'Professional Communication',
          'Conflict Resolution',
          'Assertiveness Training',
          'Active Listening',
        ];
      case 'friendship':
        return [
          'Empathetic Communication',
          'Boundary Setting',
          'Active Listening',
          'Emotional Support',
        ];
      case 'family':
        return [
          'Family Dynamics',
          'Emotional Intelligence',
          'Conflict Resolution',
          'Understanding Perspectives',
        ];
      case 'social':
        return [
          'Social Skills',
          'Conversation Starters',
          'Confidence Building',
          'Peer Communication',
        ];
      default:
        return [
          'Communication Skills',
          'Active Listening',
          'Empathy',
          'Social Awareness',
        ];
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String _formatDuration(int? duration) {
    if (duration == null) return '10-15';
    return '${duration - 2}-${duration + 3}';
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

Widget _buildStatCard({
  required String value,
  required String label,
  required Color color,
  required Color textColor,
}) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      // Make it square by setting a fixed aspect ratio
      child: AspectRatio(
        aspectRatio: 1.5, // This makes it square
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor.withOpacity(0.8),
                fontWeight: FontWeight.w400,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildSkillChip(String skill) {
  return Align(
    alignment: Alignment.centerLeft, // align left
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Color(0xFFD55E42)),
      ),
      child: Text(
        skill,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    ),
  );
}
