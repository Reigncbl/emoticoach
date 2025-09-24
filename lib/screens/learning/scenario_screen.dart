import 'package:flutter/material.dart';
import './reading_screen.dart';
import './scenario_detail_screen.dart';
import '../../utils/colors.dart';
import '../../services/scenario_service.dart';
import '../../services/user_api_service.dart';
import '../../models/scenario_models.dart';
import '../../controllers/learning_navigation_controller.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LearningNavigationController _navController =
      LearningNavigationController();

  // Missing state variables
  bool _isLoading = false;
  String? _errorMessage;
  List<Scenario> _scenarios = [];
  List<CompletedScenario> _completedScenarios = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _navController.currentTabIndex,
    );

    // Listen to navigation controller changes
    _navController.addListener(_handleNavigationChange);

    // Load scenarios when screen initializes
    _loadScenarios();
  }

  void _handleNavigationChange() {
    if (_tabController.index != _navController.currentTabIndex) {
      _tabController.animateTo(_navController.currentTabIndex);
    }
    _loadScenarios();
  }

  @override
  void dispose() {
    _navController.removeListener(_handleNavigationChange);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadScenarios() async {
    print('🔍 DEBUG: Starting to load scenarios...');
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      print('🔍 DEBUG: Calling ScenarioService.getScenarios()...');
      final scenarioData = await ScenarioService.getScenarios();
      print('🔍 DEBUG: Received ${scenarioData.length} scenario records');

      final scenarios = scenarioData.map((data) {
        print('🔍 DEBUG: Processing scenario data: $data');
        return Scenario.fromJson(data);
      }).toList();

      print('🔍 DEBUG: Successfully parsed ${scenarios.length} scenarios');

      // Load completed scenarios for current user
      List<CompletedScenario> completedScenarios = [];
      try {
        final userId = await UserApiService.getCurrentUserId();
        final completedData = await ScenarioService.getCompletedScenarios(
          userId,
        );
        completedScenarios = completedData.map((data) {
          return CompletedScenario.fromJson(data);
        }).toList();
        print(
          '🔍 DEBUG: Loaded ${completedScenarios.length} completed scenarios',
        );
      } catch (e) {
        print('🔍 DEBUG: Error loading completed scenarios: $e');
        // Don't fail the whole load if completed scenarios fail
      }

      setState(() {
        _scenarios = scenarios.where((s) => s.isActive).toList();
        _completedScenarios = completedScenarios;
        print('🔍 DEBUG: Filtered to ${_scenarios.length} active scenarios');
        _isLoading = false;
      });

      print('🔍 DEBUG: Successfully loaded scenarios!');
    } catch (e) {
      print('🔍 DEBUG: Error loading scenarios: $e');
      print('🔍 DEBUG: Error type: ${e.runtimeType}');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load scenarios: ${e.toString()}';
      });
      print('Error loading scenarios: $e');
    }
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
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading scenarios...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Error loading scenarios',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadScenarios,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

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

          // Scenarios Done Section
          if (_completedScenarios.isNotEmpty) ...[
            _buildSectionHeader('Scenarios Done', Icons.check_circle_outline),
            const SizedBox(height: 12),
            ..._completedScenarios.map(
              (completedScenario) =>
                  _buildCompletedScenarioCard(completedScenario),
            ),
            const SizedBox(height: 24),
          ],

          // Explore Section
          _buildSectionHeader('Explore', Icons.explore),
          const SizedBox(height: 12),

          if (_scenarios.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'No scenarios available at the moment.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          else
            ..._scenarios.map((scenario) => _buildScenarioCard(scenario)),
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

  Widget _buildScenarioCard(Scenario scenario, {bool isCompleted = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: ScenarioCard(
        title: scenario.title,
        description: scenario.description,
        persona: _getPersonaFromCategory(scenario.category),
        difficulty: _capitalizeFirst(scenario.difficulty),
        isReplay: isCompleted,
        scenarioRuns: isCompleted ? 1 : 0,
        rating: 4.2, // Default rating - can be enhanced with user ratings
        totalRatings: 150, // Default - can be enhanced with actual data
        duration: scenario.formattedDuration,
        icon: _getIconFromCategory(scenario.category),
        color: _getColorFromCategory(scenario.category),
        onTap: () => _startScenario(scenario),
      ),
    );
  }

  Widget _buildCompletedScenarioCard(CompletedScenario completedScenario) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: ScenarioCard(
        title: completedScenario.title,
        description: completedScenario.description,
        persona: _getPersonaFromCategory(completedScenario.category),
        difficulty: _capitalizeFirst(completedScenario.difficulty),
        isReplay: true,
        scenarioRuns: completedScenario.completionCount,
        rating: completedScenario.averageScore ?? 4.2,
        totalRatings: 150, // Default - can be enhanced with actual data
        duration: completedScenario.formattedDuration,
        icon: _getIconFromCategory(completedScenario.category),
        color: _getColorFromCategory(completedScenario.category),
        onTap: () => _replayScenario(completedScenario),
      ),
    );
  }

  void _replayScenario(CompletedScenario completedScenario) {
    // Convert CompletedScenario to Scenario for detail screen
    final scenario = Scenario(
      id: completedScenario.scenarioId,
      title: completedScenario.title,
      description: completedScenario.description,
      category: completedScenario.category,
      difficulty: completedScenario.difficulty,
      estimatedDuration: completedScenario.estimatedDuration,
      isActive: true,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScenarioDetailScreen(scenario: scenario),
      ),
    );
  }

  void _startScenario(Scenario scenario) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScenarioDetailScreen(scenario: scenario),
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

  IconData _getIconFromCategory(String category) {
    switch (category.toLowerCase()) {
      case 'workplace':
      case 'professional':
        return Icons.business;
      case 'friendship':
        return Icons.people;
      case 'family':
        return Icons.family_restroom;
      case 'social':
        return Icons.school;
      default:
        return Icons.chat;
    }
  }

  Color _getColorFromCategory(String category) {
    switch (category.toLowerCase()) {
      case 'workplace':
      case 'professional':
        return kArticleOrange;
      case 'friendship':
        return Colors.pink[600]!;
      case 'family':
        return Colors.purple[600]!;
      case 'social':
        return kScenarioBlue;
      default:
        return kBrightBlue;
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
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
                title: const Text('Beginner'),
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
}
