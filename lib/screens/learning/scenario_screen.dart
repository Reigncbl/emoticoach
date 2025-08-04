import 'package:flutter/material.dart';
import 'reading_screen.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Modules'),
        centerTitle: false,
        actions: [
          IconButton(icon: const Icon(Icons.info_outline), onPressed: () {}),
        ],
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
        children: [
          // 📍 Chat Scenarios Tab
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                // 🔍 Search + Filter Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search for specific chat scenarios...',
                          suffixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: const Color(0xFFD8DDE4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(50),
                            borderSide:
                                BorderSide.none, // remove border if desired
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
                      onPressed: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ✅ Section: Scenarios Done
                const Text(
                  'Scenarios Done',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ScenarioCard(
                  title: 'Ask for Extension',
                  description:
                      'Request a deadline from your professor for your final project.',
                  persona: 'Professor John Doe',
                  difficulty: 'Hard',
                  isReplay: true,
                ),

                const SizedBox(height: 24),

                // 🔎 Section: Explore
                const Text(
                  'Explore',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ScenarioCard(
                  title: 'Console a Friend',
                  description: 'Be there for a friend who failed their exam.',
                  persona: 'A student who failed their exam.',
                  difficulty: 'Medium',
                  isReplay: false,
                ),
                const SizedBox(height: 12),
                ScenarioCard(
                  title: 'Talk to a New Classmate',
                  description:
                      'They just transferred, talk to the new student and introduce yourself.',
                  persona: 'The new transfer student.',
                  difficulty: 'Easy',
                  isReplay: false,
                ),
              ],
            ),
          ),

          // 📄 Readings Tab
          const ReadingScreen(),
        ],
      ),
    );
  }
}

class ScenarioCard extends StatelessWidget {
  final String title;
  final String description;
  final String persona;
  final String difficulty;
  final bool isReplay;

  const ScenarioCard({
    super.key,
    required this.title,
    required this.description,
    required this.persona,
    required this.difficulty,
    required this.isReplay,
  });

  Color _getDifficultyColor(String level) {
    switch (level) {
      case 'Hard':
        return const Color(0xFFF5D8CB);
      case 'Medium':
        return const Color(0xFFC7D3E2);
      case 'Easy':
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
            color:
                (isReplay ? const Color(0xFFF5D8CB) : const Color(0xFFC7D3E2))
                    .withOpacity(0.4),
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
              // 🔥 Title + Difficulty tag
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

              // 📝 Description
              Text(description),

              const SizedBox(height: 12),

              // 👤 Persona line
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Persona: $persona',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 🚀 Replay or Start Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isReplay
                      ? Colors.red.shade300
                      : Colors.blue.shade600,
                  minimumSize: const Size.fromHeight(40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {},
                child: Text(
                  isReplay ? 'Replay Scenario' : 'Start Scenario',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ⭐ Placeholder for ratings
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Scenario Runs: 2', style: TextStyle(fontSize: 12)),
                  Text('⭐️⭐️⭐️⭐️☆ (300)', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
