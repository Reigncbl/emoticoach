import 'package:flutter/material.dart';
import './reading_screen.dart';
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
                const Icon(Icons.info_outline, color: Colors.black54),
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
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
            ],
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
          ),
          const SizedBox(height: 24),

          // Explore Section
          _buildSectionHeader('Explore', Icons.explore),
          const SizedBox(height: 12),
          ScenarioCard(
            title: 'Console a Friend',
            description: 'Be there for a friend who failed their exam.',
            persona: 'A student who failed their exam',
            difficulty: 'Medium',
            isReplay: false,
            scenarioRuns: 0,
            rating: 4.5,
            totalRatings: 150,
          ),
          const SizedBox(height: 12),
          ScenarioCard(
            title: 'Talk to a New Classmate',
            description:
                'They just transferred, talk to the new student and introduce yourself.',
            persona: 'The new transfer student',
            difficulty: 'Easy',
            isReplay: false,
            scenarioRuns: 0,
            rating: 4.0,
            totalRatings: 200,
          ),
          const SizedBox(height: 12),
          ScenarioCard(
            title: 'Job Interview Practice',
            description:
                'Practice your interview skills with a potential employer.',
            persona: 'HR Manager',
            difficulty: 'Hard',
            isReplay: false,
            scenarioRuns: 0,
            rating: 4.7,
            totalRatings: 450,
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
              const Text('Filter by:'),
              const SizedBox(height: 16),
              // TODO: Add filter options
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + Difficulty tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

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
                      'Persona: $persona',
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
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
                  Text(
                    'Runs: $scenarioRuns',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Row(
                    children: [
                      Icon(Icons.star, size: 14, color: Colors.amber.shade600),
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
                  onPressed: () => _startScenario(context),
                  child: Text(
                    isReplay ? 'Replay Scenario' : 'Start Scenario',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
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
