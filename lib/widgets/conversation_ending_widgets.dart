import '../../utils/colors.dart';
import '../../models/scenario_models.dart';
import '../services/api_service.dart';

/// Dialog that appears when the AI suggests ending the conversation
class ConversationEndingDialog extends StatelessWidget {
  final String aiSuggestion;
  final String characterName;
  final List<ConversationMessage> conversationHistory;
  final VoidCallback onContinue;
  final VoidCallback onEnd;

  const ConversationEndingDialog({
    super.key,
    required this.aiSuggestion,
    required this.characterName,
    required this.conversationHistory,
    required this.onContinue,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.chat_bubble_outline, color: kDarkOrange),
          const SizedBox(width: 8),
          Text('$characterName suggests...'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Text(
              aiSuggestion,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'What would you like to do?',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onContinue,
          child: const Text('Continue Chatting'),
        ),
        ElevatedButton(
          onPressed: onEnd,
          style: ElevatedButton.styleFrom(
            backgroundColor: kDarkOrange,
            foregroundColor: Colors.white,
          ),
          child: const Text('End & Evaluate'),
        ),
      ],
    );
  }
}

/// Button that manually ends the conversation
class EndConversationButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isEnabled;

  const EndConversationButton({
    super.key,
    required this.onPressed,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: ElevatedButton.icon(
        onPressed: isEnabled ? onPressed : null,
        icon: const Icon(Icons.stop_circle_outlined, size: 18),
        label: const Text('End Chat'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

/// Progress indicator showing conversation progress
class ConversationProgressIndicator extends StatelessWidget {
  final int messageCount;
  final int suggestedMinimum;
  final int suggestedMaximum;

  const ConversationProgressIndicator({
    super.key,
    required this.messageCount,
    this.suggestedMinimum = 5,
    this.suggestedMaximum = 15,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (messageCount / suggestedMaximum).clamp(0.0, 1.0);
    final isOptimalLength =
        messageCount >= suggestedMinimum && messageCount <= suggestedMaximum;

    Color progressColor;
    String statusText;

    if (messageCount < suggestedMinimum) {
      progressColor = Colors.orange;
      statusText = 'Building conversation...';
    } else if (isOptimalLength) {
      progressColor = Colors.green;
      statusText = 'Good conversation depth';
    } else {
      progressColor = Colors.red;
      statusText = 'Consider wrapping up';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.chat, size: 16, color: progressColor),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$messageCount msgs',
                style: TextStyle(
                  fontSize: 12,
                  color: progressColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
              if (messageCount >= suggestedMaximum)
                Icon(Icons.warning_amber, size: 16, color: Colors.red[400]),
            ],
          ),
        ],
      ),
    );
  }
}

/// Service to handle conversation ending logic
class ConversationEndingService {
  final APIService _apiService = APIService();

  /// Check if conversation should end based on AI analysis
  Future<ConversationEndingSuggestion?> checkForNaturalEnding(
    List<ConversationMessage> conversationHistory,
    int scenarioId,
  ) async {
    try {
      // This would call your backend conversation tracker
      final response = await _apiService.checkConversationFlow(
        conversationHistory: conversationHistory,
        scenarioId: scenarioId,
      );

      if (response.shouldEnd && response.confidence > 0.6) {
        return ConversationEndingSuggestion(
          shouldEnd: true,
          confidence: response.confidence,
          reason: response.reason,
          suggestedMessage: response.suggestedEndingMessage,
        );
      }
      return null;
    } catch (e) {
      print('Error checking conversation flow: $e');
      return null;
    }
  }

  /// Show ending confirmation dialog
  Future<bool> showEndingConfirmation(
    BuildContext context,
    String characterName,
    List<ConversationMessage> conversationHistory,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('End Conversation with $characterName?'),
            content: const Text(
              'Are you sure you want to end this conversation? You\'ll receive an evaluation of your communication skills.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Continue Chatting'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDarkOrange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('End & Evaluate'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

/// Data model for conversation ending suggestions
class ConversationEndingSuggestion {
  final bool shouldEnd;
  final double confidence;
  final String reason;
  final String? suggestedMessage;

  ConversationEndingSuggestion({
    required this.shouldEnd,
    required this.confidence,
    required this.reason,
    this.suggestedMessage,
  });
}

/// Helper function to determine if manual end button should be enabled
bool shouldShowEndButton(int messageCount, {int minimumMessages = 3}) {
  return messageCount >= minimumMessages;
}
