import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../../utils/temp_api_service.dart';
import '../../models/scenario_models.dart';
import 'evaluation.dart';

class ScenarioScreen extends StatefulWidget {
  final int scenarioId;
  final String scenarioTitle;
  final String aiPersona;
  final String initialMessage;

  const ScenarioScreen({
    super.key,
    required this.scenarioId,
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

  bool _isLoading = false;
  bool _isInitialized = false;
  String? _characterName;
  List<ConversationMessage> _conversationHistory = [];

  @override
  void initState() {
    super.initState();
    _initializeConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeConversation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.startConversation(widget.scenarioId);

      if (response.success && response.firstMessage != null) {
        setState(() {
          _characterName = response.characterName ?? widget.aiPersona;
          _messages.add(
            ChatMessage(
              text: response.firstMessage!,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _conversationHistory.add(
            ConversationMessage(
              role: 'assistant',
              content: response.firstMessage!,
            ),
          );
          _isInitialized = true;
        });
      } else {
        // Fallback to provided initial message
        setState(() {
          _characterName = widget.aiPersona;
          _messages.add(
            ChatMessage(
              text: widget.initialMessage,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _conversationHistory.add(
            ConversationMessage(
              role: 'assistant',
              content: widget.initialMessage,
            ),
          );
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing conversation: $e');
      // Fallback to provided initial message
      setState(() {
        _characterName = widget.aiPersona;
        _messages.add(
          ChatMessage(
            text: widget.initialMessage,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _conversationHistory.add(
          ConversationMessage(
            role: 'assistant',
            content: widget.initialMessage,
          ),
        );
        _isInitialized = true;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isLoading) return;

    final userMessage = _messageController.text.trim();

    setState(() {
      _messages.add(
        ChatMessage(text: userMessage, isUser: true, timestamp: DateTime.now()),
      );
      _conversationHistory.add(
        ConversationMessage(role: 'user', content: userMessage),
      );
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final request = ChatRequest(
        message: userMessage,
        conversationHistory: _conversationHistory,
      );

      final response = await _apiService.sendMessage(request);

      if (response.success && response.response != null) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: response.response!,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _conversationHistory.add(
            ConversationMessage(role: 'assistant', content: response.response!),
          );
          if (response.characterName != null) {
            _characterName = response.characterName;
          }
        });
      } else {
        setState(() {
          _messages.add(
            ChatMessage(
              text: "Sorry, I encountered an error. Please try again.",
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });
      }
    } catch (e) {
      print('Error sending message: $e');
      setState(() {
        _messages.add(
          ChatMessage(
            text: "Sorry, I'm having trouble connecting. Please try again.",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
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

  void _navigateToEvaluation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EvaluationScreen(
          conversationHistory: _conversationHistory,
          characterName: _characterName ?? widget.aiPersona,
        ),
      ),
    );
  }

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
              'AI Persona: ${_characterName ?? widget.aiPersona}',
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: CustomContinueButtonSmall(
              onPressed: _conversationHistory.length > 1
                  ? _navigateToEvaluation
                  : null,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading && !_isInitialized) const LinearProgressIndicator(),
          Expanded(
            child: _isInitialized
                ? ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return ChatBubble(message: _messages[index]);
                    },
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          if (_isLoading && _isInitialized)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
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
                    enabled: _isInitialized && !_isLoading,
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
                CustomSendButton(
                  onPressed: _isInitialized && !_isLoading
                      ? _sendMessage
                      : null,
                ),
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
  final VoidCallback? onPressed;

  const CustomSendButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: onPressed != null ? Theme.of(context).primaryColor : Colors.grey,
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
  final VoidCallback? onPressed;

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
        backgroundColor: onPressed != null ? kDarkOrange : Colors.grey,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
        minimumSize: Size.zero,
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

// Chat message model
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
