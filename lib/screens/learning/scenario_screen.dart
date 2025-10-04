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
  final TextEditingController _searchController = TextEditingController();
  // Missing state variables
  bool _isLoading = false;
  String? _errorMessage;
  List<Scenario> _scenarios = [];
  List<Scenario> _filteredScenarios = [];
  List<CompletedScenario> _completedScenarios = [];

  // Filter state
  Set<String> _selectedDifficulties = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _navController.currentTabIndex,
    );

    // Listen to tab controller changes
    _tabController.addListener(_onTabChanged);

    // Listen to navigation controller changes
    _navController.addListener(_handleNavigationChange);

    // Load scenarios when screen initializes
    _loadScenarios();
    _searchController.addListener(_filterScenario);
  }

  void _handleNavigationChange() {
    if (_tabController.index != _navController.currentTabIndex) {
      _tabController.animateTo(_navController.currentTabIndex);
    }
    // Only reload scenarios when switching TO the Chat Scenarios tab (index 0)
    if (_navController.currentTabIndex == 0) {
      _loadScenarios();
    }
  }

  void _filterScenario() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredScenarios = _scenarios.where((scenario) {
        // Search filter
        bool matchesSearch = true;
        if (query.isNotEmpty) {
          final t = scenario.title.toLowerCase();
          final d = scenario.description.toLowerCase();
          final c = scenario.category.toLowerCase();
          matchesSearch =
              t.contains(query) || d.contains(query) || c.contains(query);
        }

        // Difficulty filter
        bool matchesDifficulty = true;
        if (_selectedDifficulties.isNotEmpty) {
          matchesDifficulty = _selectedDifficulties.contains(
            scenario.difficulty.toLowerCase(),
          );
        }

        return matchesSearch && matchesDifficulty;
      }).toList();
    });
  }

  void _onTabChanged() {
    debugPrint('DEBUG: Tab changed to index: ${_tabController.index}');
    // Only reload scenarios when the Chat Scenarios tab (index 0) is selected
    if (_tabController.index == 0) {
      debugPrint('DEBUG: Chat Scenarios tab selected, loading scenarios...');
      _loadScenarios();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _navController.removeListener(_handleNavigationChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadScenarios() async {
    // Prevent multiple simultaneous loads
    if (_isLoading) {
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final scenarioData = await ScenarioService.getScenarios();
      debugPrint(' DEBUG: Received ${scenarioData.length} scenario records');

      final scenarios = scenarioData.map((data) {
        debugPrint(' DEBUG: Processing scenario data: $data');
        return Scenario.fromJson(data);
      }).toList();

      // Load completed scenarios for current user
      List<CompletedScenario> completedScenarios = [];
      try {
        final userId = await UserApiService.getCurrentUserId();
        debugPrint(' DEBUG: Current user ID: $userId');

        final completedData = await ScenarioService.getCompletedScenarios(
          userId,
        );

        completedScenarios = completedData.map((data) {
          return CompletedScenario.fromJson(data);
        }).toList();

        debugPrint(
          ' DEBUG: Successfully parsed ${completedScenarios.length} completed scenarios',
        );
      } catch (e) {
        debugPrint('DEBUG: Error loading completed scenarios: $e');
        debugPrint('DEBUG: Error type: ${e.runtimeType}');
        debugPrint('DEBUG: Stack trace: ${StackTrace.current}');
        // Don't fail the whole load if completed scenarios fail
      }

      setState(() {
        _scenarios = scenarios.where((s) => s.isActive).toList();
        _filteredScenarios =
            _scenarios; // Initialize filtered list with all scenarios
        _completedScenarios = completedScenarios;
        debugPrint(' DEBUG: Filtered to ${_scenarios.length} active scenarios');
        debugPrint(
          ' DEBUG: Set _completedScenarios to ${_completedScenarios.length} items',
        );
        debugPrint(
          ' DEBUG: _completedScenarios.isNotEmpty = ${_completedScenarios.isNotEmpty}',
        );
        _isLoading = false;
      });

      debugPrint(' DEBUG: Successfully loaded scenarios!');
    } catch (e) {
      debugPrint(' DEBUG: Error loading scenarios: $e');
      debugPrint(' DEBUG: Error type: ${e.runtimeType}');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load scenarios: ${e.toString()}';
      });
      debugPrint('Error loading scenarios: $e');
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
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search for specific chat scenarios...',
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : const Icon(Icons.search),
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
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: _showScenarioFilterDialog,
                  ),
                  if (_selectedDifficulties.isNotEmpty)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: kBrightBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_selectedDifficulties.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
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

          if (_filteredScenarios.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'No scenarios found matching your search.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          else
            ..._filteredScenarios.map(
              (scenario) => _buildScenarioCard(scenario),
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
      child: CompletedScenarioCard(
        completedScenario: completedScenario,
        persona: _getPersonaFromCategory(completedScenario.category),
        icon: _getIconFromCategory(completedScenario.category),
        color: _getColorFromCategory(completedScenario.category),
        onReplay: () => _replayScenario(completedScenario),
        onViewDetails: () => _showCompletionDetails(completedScenario),
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

  // Filter scenarios by difficulty
  void _showScenarioFilterDialog() {
    // Create a temporary copy of selected difficulties
    Set<String> tempSelectedDifficulties = Set.from(_selectedDifficulties);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Filter Scenarios'),
                  if (tempSelectedDifficulties.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setDialogState(() {
                          tempSelectedDifficulties.clear();
                        });
                      },
                      child: const Text(
                        'Clear All',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter by difficulty:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Beginner'),
                    value: tempSelectedDifficulties.contains('beginner'),
                    activeColor: Colors.green,
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          tempSelectedDifficulties.add('beginner');
                        } else {
                          tempSelectedDifficulties.remove('beginner');
                        }
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Intermediate'),
                    value: tempSelectedDifficulties.contains('intermediate'),
                    activeColor: Colors.orange,
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          tempSelectedDifficulties.add('intermediate');
                        } else {
                          tempSelectedDifficulties.remove('intermediate');
                        }
                      });
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Advanced'),
                    value: tempSelectedDifficulties.contains('advanced'),
                    activeColor: Colors.red,
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          tempSelectedDifficulties.add('advanced');
                        } else {
                          tempSelectedDifficulties.remove('advanced');
                        }
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrightBlue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedDifficulties = tempSelectedDifficulties;
                      _filterScenario(); // Apply filters
                    });
                    Navigator.pop(context);
                  },
                  child: Text(
                    tempSelectedDifficulties.isEmpty
                        ? 'Show All'
                        : 'Apply (${tempSelectedDifficulties.length})',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCompletionDetails(CompletedScenario completedScenario) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${completedScenario.title} - Results'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  'Completed',
                  '${completedScenario.completedAt.day}/${completedScenario.completedAt.month}/${completedScenario.completedAt.year}',
                ),
                _buildDetailRow(
                  'Duration',
                  completedScenario.formattedCompletionTime,
                ),
                _buildDetailRow(
                  'Messages Sent',
                  '${completedScenario.totalMessages ?? 'N/A'}',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Communication Scores:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (completedScenario.finalClarityScore != null)
                  _buildScoreRow(
                    'Clarity',
                    completedScenario.finalClarityScore!,
                  ),
                if (completedScenario.finalEmpathyScore != null)
                  _buildScoreRow(
                    'Empathy',
                    completedScenario.finalEmpathyScore!,
                  ),
                if (completedScenario.finalAssertivenessScore != null)
                  _buildScoreRow(
                    'Assertiveness',
                    completedScenario.finalAssertivenessScore!,
                  ),
                if (completedScenario.finalAppropriatenessScore != null)
                  _buildScoreRow(
                    'Appropriateness',
                    completedScenario.finalAppropriatenessScore!,
                  ),
                const SizedBox(height: 12),
                if (completedScenario.averageScore != null)
                  _buildDetailRow(
                    'Overall Score',
                    completedScenario.formattedAverageScore,
                  ),
                if (completedScenario.userRating != null)
                  _buildDetailRow(
                    'Your Rating',
                    completedScenario.formattedRating,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _replayScenario(completedScenario);
              },
              child: const Text('Replay'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String skill, int score) {
    Color scoreColor;
    if (score >= 8) {
      scoreColor = Colors.green;
    } else if (score >= 6) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(skill, style: const TextStyle(fontSize: 14)),
          ),
          Container(
            width: 100,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              widthFactor: score / 10.0,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: scoreColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$score/10',
            style: TextStyle(fontWeight: FontWeight.bold, color: scoreColor),
          ),
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

class CompletedScenarioCard extends StatelessWidget {
  final CompletedScenario completedScenario;
  final String persona;
  final IconData icon;
  final Color color;
  final VoidCallback onReplay;
  final VoidCallback onViewDetails;

  const CompletedScenarioCard({
    super.key,
    required this.completedScenario,
    required this.persona,
    required this.icon,
    required this.color,
    required this.onReplay,
    required this.onViewDetails,
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
            color: Colors.green.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onViewDetails,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with completion badge
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
                        completedScenario.title,
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
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Completed',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  completedScenario.description,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 12),

                // Completion stats
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem(
                            'Completed',
                            '${completedScenario.completedAt.day}/${completedScenario.completedAt.month}',
                          ),
                          _buildStatItem(
                            'Duration',
                            completedScenario.formattedCompletionTime,
                          ),
                          if (completedScenario.averageScore != null)
                            _buildStatItem(
                              'Score',
                              completedScenario.formattedAverageScore,
                            ),
                        ],
                      ),
                      if (completedScenario.userRating != null)
                        Column(
                          children: [
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.star, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'Your Rating: ${completedScenario.userRating}/5',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
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
                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: color),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: onViewDetails,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.analytics_outlined,
                              size: 16,
                              color: color,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'View Details',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBrightBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: onReplay,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.replay, size: 16),
                            const SizedBox(width: 6),
                            const Text(
                              'Replay',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}
