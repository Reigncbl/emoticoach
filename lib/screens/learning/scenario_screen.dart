import 'package:flutter/material.dart';
import './reading_screen.dart';
import './scenario.dart';
import '../debug_connection.dart';
import '../../utils/colors.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Learning Modules",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.bug_report, color: Colors.black54),
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
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.black54),
                  onPressed: _showInfoDialog,
                ),
              ],
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(width: 3.0, color: Color(0xFF0F55B2)),
            ),
            labelColor: const Color(0xFF0F55B2),
            unselectedLabelColor: Colors.black,
            tabs: const [
              Tab(
                child: Text(
                  'Chat Scenarios',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              Tab(
                child: Text(
                  'Readings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [_buildScenariosTab(), const ReadingScreen()],
        ),
      ),
    );
  }

  Widget _buildScenariosTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search + Filter Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search for specific chat scenarios...',
                    suffixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: const Color(0xFFF0F0F0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showScenarioFilterDialog,
              ),
            ],
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
          const SizedBox(height: 24),

          // Scenarios Done Section
          _buildSectionHeader('Scenarios Done', Icons.check_circle_outline),
          const SizedBox(height: 12),
          ScenarioCard(
            title: 'Ask for Extension',
            description:
                'Request a deadline extension from your professor for your final project.',
            persona: 'Professor John Doe',
            difficulty: 'Hard',
            isReplay: true,
            scenarioRuns: 2,
            rating: 4.2,
            totalRatings: 300,
            duration: '12-15 min',
            icon: Icons.school,
            color: kScenarioBlue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScenarioScreen(
                    scenarioTitle: 'Ask for Extension',
                    aiPersona: 'Professor John Doe',
                    initialMessage:
                        'I see you wanted to discuss your final project. What can I help you with?',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Explore Section
          _buildSectionHeader('Explore', Icons.explore),
          const SizedBox(height: 12),

          ScenarioCard(
            title: 'Difficult Academic Feedback',
            description:
                'Practice receiving and responding to challenging feedback from a professor about your academic performance.',
            persona: 'Prof. Cedric',
            difficulty: 'Medium',
            isReplay: false,
            scenarioRuns: 0,
            rating: 4.3,
            totalRatings: 180,
            duration: '10-15 min',
            icon: Icons.school,
            color: kScenarioBlue,
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
          const SizedBox(height: 12),

          ScenarioCard(
            title: 'Console a Friend',
            description: 'Be there for a friend who failed their exam.',
            persona: 'A student who failed their exam',
            difficulty: 'Easy',
            isReplay: false,
            scenarioRuns: 0,
            rating: 4.5,
            totalRatings: 150,
            duration: '8-12 min',
            icon: Icons.people,
            color: Colors.pink[600]!,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScenarioScreen(
                    scenarioTitle: 'Console a Friend',
                    aiPersona: 'A student who failed their exam',
                    initialMessage:
                        'Hey... I just got my exam results back and I failed. I don\'t know what to do.',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          ScenarioCard(
            title: 'Workplace Conflict Resolution',
            description:
                'Navigate a challenging conversation with a colleague about a work disagreement.',
            persona: 'Manager Sarah',
            difficulty: 'Hard',
            isReplay: false,
            scenarioRuns: 0,
            rating: 4.1,
            totalRatings: 220,
            duration: '15-20 min',
            icon: Icons.business,
            color: kArticleOrange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScenarioScreen(
                    scenarioTitle: 'Workplace Conflict Resolution',
                    aiPersona: 'Manager Sarah',
                    initialMessage:
                        'Hi there, I think we need to talk about what happened in yesterday\'s meeting. I noticed some tension and I\'d like to work through it together.',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          ScenarioCard(
            title: 'Giving Constructive Feedback',
            description:
                'Practice delivering feedback to a team member in a supportive and effective way.',
            persona: 'Team Member Alex',
            difficulty: 'Medium',
            isReplay: false,
            scenarioRuns: 0,
            rating: 4.4,
            totalRatings: 195,
            duration: '10-15 min',
            icon: Icons.feedback,
            color: Colors.green[600]!,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScenarioScreen(
                    scenarioTitle: 'Giving Constructive Feedback',
                    aiPersona: 'Team Member Alex',
                    initialMessage:
                        'Hey! Thanks for setting up this meeting. I\'m ready to hear your thoughts on my recent project work.',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          ScenarioCard(
            title: 'Difficult Customer Service',
            description:
                'Handle a frustrated customer complaint with empathy and professionalism.',
            persona: 'Customer Jamie',
            difficulty: 'Easy',
            isReplay: false,
            scenarioRuns: 0,
            rating: 4.0,
            totalRatings: 200,
            duration: '8-12 min',
            icon: Icons.support_agent,
            color: Colors.purple[600]!,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScenarioScreen(
                    scenarioTitle: 'Difficult Customer Service',
                    aiPersona: 'Customer Jamie',
                    initialMessage:
                        'I am extremely frustrated! I\'ve been trying to resolve this issue for weeks and no one seems to be able to help me. This is completely unacceptable!',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Learning Modules'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chat Scenarios',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Practice real-world conversations with AI personas.'),
              SizedBox(height: 12),
              Text('Readings', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                'Learn from articles, guides, and e-books about communication.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  void _showScenarioFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Filter Scenarios'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Filter by difficulty:'),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Easy'),
                value: false,
                onChanged: (value) {},
              ),
              CheckboxListTile(
                title: const Text('Medium'),
                value: false,
                onChanged: (value) {},
              ),
              CheckboxListTile(
                title: const Text('Hard'),
                value: false,
                onChanged: (value) {},
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
  }
}

class ScenarioCard extends StatelessWidget {
  final String title;
  final String description;
  final String persona;
  final String difficulty;
  final bool isReplay;
  final int scenarioRuns;
  final double rating;
  final int totalRatings;
  final String duration;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const ScenarioCard({
    super.key,
    required this.title,
    required this.description,
    required this.persona,
    required this.difficulty,
    required this.isReplay,
    required this.scenarioRuns,
    required this.rating,
    required this.totalRatings,
    required this.duration,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  Color _getDifficultyColor(String level) {
    switch (level.toLowerCase()) {
      case 'hard':
        return const Color(0xFFF5D8CB);
      case 'medium':
        return const Color(0xFFC7D3E2);
      case 'easy':
        return const Color(0xFFC4DCC6);
      default:
        return Colors.grey.shade200;
    }
  }

  Color _getDifficultyTextColor(String level) {
    switch (level.toLowerCase()) {
      case 'hard':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'easy':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _getDifficultyColor(difficulty).withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon + Title + Difficulty tag
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getDifficultyColor(difficulty),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        difficulty,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getDifficultyTextColor(difficulty),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  description,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 12),

                // Persona line
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'AI Persona: $persona',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Runs: $scenarioRuns',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 10,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 2),
                              Text(
                                duration,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 14,
                          color: Colors.amber.shade600,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${rating.toStringAsFixed(1)} ($totalRatings)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBrightBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: onTap,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isReplay ? 'Replay Scenario' : 'Start Scenario',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startScenario(BuildContext context) {
    // TODO: Navigate to scenario chat screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isReplay
              ? 'Replaying "$title" scenario...'
              : 'Starting "$title" scenario...',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
