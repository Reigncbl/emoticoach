import 'package:flutter/material.dart';
import '../../utils/colors.dart';
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

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      text: widget.initialMessage,
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: _messageController.text.trim(),
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });

    _simulateBackendResponse();
    _messageController.clear();
    _scrollToBottom();
  }

  void _simulateBackendResponse() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text:
                "This is a simulated response from the backend based on your message.",
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    });
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EvaluationScreen(),
      ),
    );
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
            Text (
              widget.scenarioTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'AI Persona: ${widget.aiPersona}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
                color: kBlack,
              )
            )
          ],
        ),
        elevation: 1,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: CustomContinueButtonSmall(
              onPressed: _navigateToNextScreen,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
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
                CustomSendButton(
                  onPressed: _sendMessage,
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
  final VoidCallback onPressed;

  const CustomSendButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(
          Icons.send,
          color: Colors.white,
        ),
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
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: kDarkOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
        minimumSize: Size.zero, // shrink to fit AppBar
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

// Reusable chat bubble widget
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[400],
              child: const Icon(
                Icons.smart_toy,
                size: 18,
                color: Colors.white,
              ),
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
                  color:
                      isUser ? Colors.blueGrey[800] : Colors.grey[800],
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
              child: const Icon(
                Icons.person,
                size: 18,
                color: Colors.white,
              ),
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
