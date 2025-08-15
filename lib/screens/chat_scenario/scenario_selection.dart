import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import 'scenario.dart';
import '../debug_connection.dart';

class ScenarioSelectionScreen extends StatelessWidget {
  const ScenarioSelectionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice Scenarios'),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DebugConnectionScreen(),
                ),
              );
            },
            tooltip: 'Debug Connection',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Choose a Scenario',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Practice your communication skills in realistic situations',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Debug Connection Card
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Having connection issues?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap the debug icon above to test your backend connection.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Scenarios List
            _buildScenarioCard(
              context,
              title: 'Difficult Academic Feedback',
              description: 'Practice receiving and responding to challenging feedback from a professor about your academic performance.',
              difficulty: 'Intermediate',
              duration: '10-15 min',
              icon: Icons.school,
              color: kScenarioBlue,
              aiPersona: 'Prof. Cedric',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ScenarioScreen(
                      scenarioTitle: 'Difficult Academic Feedback',
                      aiPersona: 'Prof. Cedric',
                      initialMessage: 'Loading conversation...',
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            _buildScenarioCard(
              context,
              title: 'Workplace Conflict Resolution',
              description: 'Navigate a challenging conversation with a colleague about a work disagreement.',
              difficulty: 'Advanced',
              duration: '15-20 min',
              icon: Icons.business,
              color: kArticleOrange,
              aiPersona: 'Manager Sarah',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ScenarioScreen(
                      scenarioTitle: 'Workplace Conflict Resolution',
                      aiPersona: 'Manager Sarah',
                      initialMessage: 'Hi there, I think we need to talk about what happened in yesterday\'s meeting. I noticed some tension and I\'d like to work through it together.',
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            _buildScenarioCard(
              context,
              title: 'Giving Constructive Feedback',
              description: 'Practice delivering feedback to a team member in a supportive and effective way.',
              difficulty: 'Intermediate',
              duration: '10-15 min',
              icon: Icons.feedback,
              color: Colors.green[600]!,
              aiPersona: 'Team Member Alex',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ScenarioScreen(
                      scenarioTitle: 'Giving Constructive Feedback',
                      aiPersona: 'Team Member Alex',
                      initialMessage: 'Hey! Thanks for setting up this meeting. I\'m ready to hear your thoughts on my recent project work.',
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            _buildScenarioCard(
              context,
              title: 'Difficult Customer Service',
              description: 'Handle a frustrated customer complaint with empathy and professionalism.',
              difficulty: 'Beginner',
              duration: '8-12 min',
              icon: Icons.support_agent,
              color: Colors.purple[600]!,
              aiPersona: 'Customer Jamie',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ScenarioScreen(
                      scenarioTitle: 'Difficult Customer Service',
                      aiPersona: 'Customer Jamie',
                      initialMessage: 'I am extremely frustrated! I\'ve been trying to resolve this issue for weeks and no one seems to be able to help me. This is completely unacceptable!',
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            _buildScenarioCard(
              context,
              title: 'Personal Relationship Discussion',
              description: 'Navigate a sensitive conversation with a friend about a personal issue.',
              difficulty: 'Advanced',
              duration: '12-18 min',
              icon: Icons.people,
              color: Colors.pink[600]!,
              aiPersona: 'Friend Taylor',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ScenarioScreen(
                      scenarioTitle: 'Personal Relationship Discussion',
                      aiPersona: 'Friend Taylor',
                      initialMessage: 'Hey, I\'m glad we could finally sit down and talk. I\'ve been feeling like there\'s been some distance between us lately, and I wanted to understand what\'s going on.',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioCard(
    BuildContext context, {
    required String title,
    required String description,
    required String difficulty,
    required String duration,
    required IconData icon,
    required Color color,
    required String aiPersona,
    required VoidCallback onTap,
  }) {
    Color difficultyColor;
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        difficultyColor = Colors.green;
        break;
      case 'intermediate':
        difficultyColor = Colors.orange;
        break;
      case 'advanced':
        difficultyColor = Colors.red;
        break;
      default:
        difficultyColor = Colors.grey;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'AI Persona: $aiPersona',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey[400],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: difficultyColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: difficultyColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      difficulty,
                      style: TextStyle(
                        color: difficultyColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          duration,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}