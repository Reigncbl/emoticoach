import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../../utils/temp_api_service.dart';
import '../../models/scenario_models.dart';

class EvaluationScreen extends StatefulWidget {
  final List<ConversationMessage> conversationHistory;
  final String characterName;

  const EvaluationScreen({
    Key? key,
    required this.conversationHistory,
    required this.characterName,
  }) : super(key: key);

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  final APIService _apiService = APIService();
  EvaluationResponse? _evaluationResponse;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _evaluateConversation();
  }

  Future<void> _evaluateConversation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final request = EvaluationRequest(
        conversationHistory: widget.conversationHistory,
      );

      final response = await _apiService.evaluateConversation(request);

      setState(() {
        _evaluationResponse = response;
        if (!response.success) {
          _error = response.error ?? 'Failed to evaluate conversation';
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Error evaluating conversation: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kWhite,
        title: const Text(
          'Conversation Evaluation',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: kWhite,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildErrorView()
            : _evaluationResponse != null
            ? _buildEvaluationView()
            : const Center(child: Text('No evaluation data available')),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'Evaluation Failed',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _evaluateConversation,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvaluationView() {
    final evaluation = _evaluationResponse!.evaluation;
    final userReplies = _evaluationResponse!.userReplies ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            color: kWhite,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assessment, color: kDarkOrange),
                      const SizedBox(width: 8),
                      Text(
                        'Assessment',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold,
                            fontSize: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Conversation with ${widget.characterName}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total messages analyzed: ${_evaluationResponse!.totalUserMessages ?? userReplies.length}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Evaluation Scores
          if (evaluation != null) ...[
            Text(
              'Performance Rating',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                ),
            ),
            const SizedBox(height: 12),

            _buildScoreCard(
              'Clarity',
              evaluation.clarity,
              'How clear and understandable your responses were',
            ),
            const SizedBox(height: 8),

            _buildScoreCard(
              'Empathy',
              evaluation.empathy,
              'How well you showed emotional awareness',
            ),
            const SizedBox(height: 8),

            _buildScoreCard(
              'Assertiveness',
              evaluation.assertiveness,
              'How confidently you expressed your thoughts',
            ),
            const SizedBox(height: 8),

            _buildScoreCard(
              'Appropriateness',
              evaluation.appropriateness,
              'How suitable your responses were for the context',
            ),

            const SizedBox(height: 20),

            // Improvement Tip
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Improvement Tip',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      evaluation.tip,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Your Messages Section
          if (userReplies.isNotEmpty) ...[
            Text(
              'Your Messages',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              color: kWhite,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Messages that were evaluated:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...userReplies.asMap().entries.map((entry) {
                      final index = entry.key;
                      final message = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding (
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: kDarkOrange,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: kWhite,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12.0),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: Text(
                                  message,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.chat),
                  label: const Text('Continue Chatting'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDarkOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(String title, int score, String description) {
    Color scoreColor;
    if (score >= 8) {
      scoreColor = Colors.green;
    } else if (score >= 6) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.red;
    }

    return Card(
      color: kWhite,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
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
                        description,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 60,
                  height: 60,
                  child: Center(
                    child: Text(
                      '$score/10',
                      style: TextStyle(
                        color: scoreColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 10.0,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
