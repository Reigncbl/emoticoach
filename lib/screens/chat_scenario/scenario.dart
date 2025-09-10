import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../../models/scenario_models.dart';
import '../../utils/api_service.dart';
import '../../widgets/conversation_ending_widgets.dart';
import 'evaluation.dart';

// NOTE: To call ScenarioScreen include 3 parameters ScenarioScreen(scenarioTitle, aiPersona, initialMessage)

class ScenarioScreen extends StatefulWidget {
  final String scenarioTitle;
  final String aiPersona;
  final String initialMessage;

  const ScenarioScreen({
    super.key,
    required this.scenarioTitle,
    required this.aiPersona,
    required this.initialMessage,
  });

  @override
  State<ScenarioScreen> createState() => _ScenarioScreenState();
}

class _ScenarioScreenState extends State<ScenarioScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final APIService _apiService = APIService();
  final ConversationEndingService _endingService = ConversationEndingService();

  bool _isTyping = false;
  int get _userMessageCount => _messages.where((m) => m.isUser).length;

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        text: widget.initialMessage,
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    setState(() {
      _messages.add(
        ChatMessage(text: userMessage, isUser: true, timestamp: DateTime.now()),
      );
      _isTyping = true;
    });

    _simulateBackendResponse();
    _messageController.clear();
    _scrollToBottom();

    // Check if conversation should end after user sends message
    _checkForNaturalEnding();
  }

  void _simulateBackendResponse() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text:
                  "This is a simulated response from the backend based on your message.",
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isTyping = false;
        });
        _scrollToBottom();
      }
    });
  }

  Future<void> _checkForNaturalEnding() async {
    final userMessageCount = _messages.where((m) => m.isUser).length;

    // Only check after minimum conversation length
    if (userMessageCount < 5) return;

    try {
      // Convert messages to conversation format
      final conversationHistory = _messages
          .map(
            (msg) => ConversationMessage(
              role: msg.isUser ? 'user' : 'assistant',
              content: msg.text,
            ),
          )
          .toList();

      final suggestion = await _endingService.checkForNaturalEnding(
        conversationHistory,
        1, // scenario ID would come from widget parameters
      );

      if (suggestion != null && suggestion.shouldEnd && mounted) {
        _showEndingSuggestionDialog(suggestion);
      }
    } catch (e) {
      print('Error checking for natural ending: $e');
    }
  }

  void _showEndingSuggestionDialog(ConversationEndingSuggestion suggestion) {
    final conversationHistory = _messages
        .map(
          (msg) => ConversationMessage(
            role: msg.isUser ? 'user' : 'assistant',
            content: msg.text,
          ),
        )
        .toList();

    showDialog(
      context: context,
      builder: (context) => ConversationEndingDialog(
        aiSuggestion: suggestion.suggestedMessage ?? suggestion.reason,
        characterName: widget.aiPersona,
        conversationHistory: conversationHistory,
        onContinue: () {
          Navigator.of(context).pop();
        },
        onEnd: () {
          Navigator.of(context).pop();
          _endConversation();
        },
      ),
    );
  }

  Future<void> _endConversation() async {
    final conversationHistory = _messages
        .map(
          (msg) => ConversationMessage(
            role: msg.isUser ? 'user' : 'assistant',
            content: msg.text,
          ),
        )
        .toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EvaluationScreen(
          conversationHistory: conversationHistory,
          characterName: widget.aiPersona,
        ),
      ),
    );
  }

  Future<void> _showManualEndDialog() async {
    final conversationHistory = _messages
        .map(
          (msg) => ConversationMessage(
            role: msg.isUser ? 'user' : 'assistant',
            content: msg.text,
          ),
        )
        .toList();

    final shouldEnd = await _endingService.showEndingConfirmation(
      context,
      widget.aiPersona,
      conversationHistory,
    );

    if (shouldEnd) {
      _endConversation();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Navigate to the next screen
  void _navigateToNextScreen() {
    showEvaluationOverlay(context);
  }

  // Navigate to previous screen
  void _navigateToPreviousScreen() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _navigateToPreviousScreen,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.scenarioTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'AI Persona: ${widget.aiPersona}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: kBlack,
              ),
            ),
          ],
        ),
        elevation: 1,
        actions: [
          // Manual end conversation button
          EndConversationButton(
            onPressed: _showManualEndDialog,
            isEnabled: _userMessageCount >= 3,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: CustomContinueButtonSmall(onPressed: _navigateToNextScreen),
          ),
        ],
      ),
      body: Column(
        children: [
          // Conversation progress indicator
          ConversationProgressIndicator(
            messageCount: _userMessageCount,
            suggestedMinimum: 5,
            suggestedMaximum: 15,
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ChatBubble(message: _messages[index]);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24.0)),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8.0),
                CustomSendButton(onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Send Button Widget
class CustomSendButton extends StatelessWidget {
  final VoidCallback onPressed;

  const CustomSendButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.send, color: Colors.white),
        onPressed: onPressed,
        tooltip: 'Send message',
      ),
    );
  }
}

// Evaluate Button for AppBar
class CustomContinueButtonSmall extends StatelessWidget {
  final VoidCallback onPressed;

  const CustomContinueButtonSmall({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      label: const Text(
        'Evaluate',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: kDarkOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
        minimumSize: Size.zero, // shrink to fit AppBar
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// Reusable chat bubble widget
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[400],
              child: const Icon(Icons.smart_toy, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8.0),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: isUser ? Colors.blueGrey[100] : Colors.grey[200],
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.blueGrey[800] : Colors.grey[800],
                  fontSize: 16.0,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8.0),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blueGrey[300],
              child: const Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

// Temporary inline model
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
