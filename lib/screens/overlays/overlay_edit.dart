import 'dart:async';
import 'package:flutter/services.dart';
import '../../utils/colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/api_service.dart';

class EditOverlayScreen extends StatefulWidget {
  final String initialText;
  final String selectedContact;
  final String contactPhone;
  final String userPhoneNumber;
  final VoidCallback onBack;

  const EditOverlayScreen({
    super.key,
    required this.initialText,
    required this.selectedContact,
    required this.contactPhone,
    required this.userPhoneNumber,
    required this.onBack,
  });

  @override
  State<EditOverlayScreen> createState() => _EditOverlayScreenState();
}

class _EditOverlayScreenState extends State<EditOverlayScreen> {
  final APIService _apiService = APIService();
  late TextEditingController _responseController;
  late TextEditingController _shortenController;
  late FocusNode _textFieldFocusNode;
  String _selectedTone = "Empathetic";
  String _latestMessage = "No message available";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _responseController = TextEditingController(text: widget.initialText);
    _shortenController = TextEditingController();
    _textFieldFocusNode = FocusNode();
    _fetchLatestMessage();

    // Add a slight delay to ensure the overlay is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupInputFocus();
    });
  }

  void _setupInputFocus() {
    // Ensure the text field can receive focus in overlay context
    if (mounted) {
      _textFieldFocusNode.requestFocus();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _textFieldFocusNode.unfocus();
        }
      });
    }
  }

  Future<void> _fetchLatestMessage() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final nameParts = widget.selectedContact.split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
      final lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';

      final response = await _apiService.getTelegramMessages(
        phoneNumber: widget.userPhoneNumber,
        contactPhone: widget.contactPhone,
        firstName: firstName,
        lastName: lastName,
      );

      if (response['success'] == true) {
        final responseData = response['data'] ?? response;
        final messages = responseData['messages'] as List<dynamic>? ?? [];
        final latestMessage = _getLatestContactMessage(messages);

        setState(() {
          _latestMessage = latestMessage;
          _isLoading = false;
        });
      } else {
        setState(() {
          _latestMessage = 'Unable to load message';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _latestMessage = 'Error loading message';
        _isLoading = false;
      });
    }
  }

  String _getLatestContactMessage(List<dynamic> messages) {
    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      final from = message['from']?.toString() ?? '';
      final messageText = message['text']?.toString() ?? '';

      final isFromContact =
          from.toLowerCase() != '' &&
          from.toLowerCase() != widget.userPhoneNumber.replaceAll('+', '') &&
          messageText.isNotEmpty;

      if (isFromContact) {
        return messageText;
      }
    }
    return 'No recent messages found';
  }

  Future<void> _modifyResponse(String instruction) async {
    try {
      // Show loading feedback
      _showCopyFeedbackDialog('Modifying response...', Colors.blue);

      // Simulate API call or implement actual modification logic
      await Future.delayed(const Duration(seconds: 1));

      // For now, just add the instruction as a prefix
      String currentText = _responseController.text;
      String modifiedText = "";

      if (instruction.toLowerCase().contains('shorter') ||
          instruction.toLowerCase().contains('brief')) {
        // Simulate shortening
        List<String> sentences = currentText.split('. ');
        modifiedText = sentences.take(1).join('. ');
        if (!modifiedText.endsWith('.')) modifiedText += '.';
      } else if (instruction.toLowerCase().contains('formal')) {
        modifiedText = "I appreciate your message. $currentText";
      } else if (instruction.toLowerCase().contains('casual')) {
        modifiedText = "Hey! $currentText 😊";
      } else {
        // Generic modification
        modifiedText = "$currentText (Modified: $instruction)";
      }

      setState(() {
        _responseController.text = modifiedText;
      });

      _shortenController.clear();
      _showCopyFeedbackDialog('Response modified successfully!', Colors.green);
    } catch (e) {
      _showCopyFeedbackDialog('Failed to modify response', Colors.red);
    }
  }

  @override
  void dispose() {
    _responseController.dispose();
    _shortenController.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final containerWidth = screenWidth;
    final maxWidth = 600.0;
    final finalWidth = containerWidth > maxWidth ? maxWidth : containerWidth;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Container(
          width: finalWidth,
          height: 550,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(),
              _buildMessageHeader(),
              _buildMainContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.transparent,
                  child: SvgPicture.asset(
                    'assets/icons/AI-Chat-nav.svg',
                    width: 40,
                    height: 40,
                    colorFilter: const ColorFilter.mode(
                      kPrimaryBlue,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onBack,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.arrow_back,
                      color: kPrimaryBlue,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0057E4), Color(0xFF006EFF)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 12),
                Text(
                  'Message from ${widget.selectedContact}:',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _isLoading
                ? const Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Loading message...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  )
                : Text(
                    _latestMessage.isNotEmpty
                        ? '"$_latestMessage"'
                        : 'No message available',
                    style: const TextStyle(
                      color: kWhite,
                      fontSize: 13,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside text field
          FocusScope.of(context).unfocus();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // RESPONSE CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "put the tone of the response here",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _responseController.text, // Suggested response
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // COPY BUTTON
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryBlue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.copy, size: 16, color: Colors.white),
                  label: const Text(
                    "Copy Text",
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: _responseController.text),
                    );
                    _showCopyFeedbackDialog(
                      'Text copied to clipboard!',
                      Colors.green,
                    );
                  },
                ),
              ),
              const Spacer(),
              // TONE BUTTONS
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildToneChip("Formal"),
                  _buildToneChip("Casual"),
                  _buildToneChip("Direct"),
                  _buildToneChip("Neutral"),
                ],
              ),
              const SizedBox(height: 8),
              // SHORTEN TEXT INPUT & SEND BUTTON
              GestureDetector(
                onTap: () {
                  // Force focus and show keyboard
                  FocusScope.of(context).requestFocus(_textFieldFocusNode);
                  _textFieldFocusNode.requestFocus();
                },
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _shortenController,
                          focusNode: _textFieldFocusNode,
                          autofocus: false,
                          enableInteractiveSelection: true,
                          textInputAction: TextInputAction.send,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.sentences,
                          onTap: () {
                            // Ensure focus is properly set on tap
                            if (!_textFieldFocusNode.hasFocus) {
                              _textFieldFocusNode.requestFocus();
                            }
                            // Force show keyboard
                            SystemChannels.textInput.invokeMethod(
                              'TextInput.show',
                            );
                          },
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              _modifyResponse(value.trim());
                            }
                          },
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            hintText: "Type instructions to modify response...",
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(4),
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: kPrimaryBlue,
                            padding: const EdgeInsets.all(8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            if (_shortenController.text.trim().isNotEmpty) {
                              _modifyResponse(_shortenController.text.trim());
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCopyFeedbackDialog(String message, Color backgroundColor) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext dialogContext) {
        // Auto-dismiss after 2 seconds
        Timer(const Duration(seconds: 2), () {
          if (mounted && Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildToneChip(String label) {
    final bool selected = _selectedTone == label;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTone = label);
        _applyToneToResponse(label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kPrimaryBlue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? kPrimaryBlue : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : Colors.black87,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _applyToneToResponse(String tone) {
    String baseText = widget.initialText;
    String modifiedText = baseText;

    switch (tone.toLowerCase()) {
      case 'empathetic':
        modifiedText = "I understand how you feel. $baseText";
        break;
      case 'formal':
        modifiedText = "Thank you for your message. $baseText";
        break;
      case 'casual':
        modifiedText = "Hey! $baseText 😊";
        break;
      case 'direct':
        // Keep it short and to the point
        List<String> sentences = baseText.split('. ');
        modifiedText = sentences.first;
        if (!modifiedText.endsWith('.')) modifiedText += '.';
        break;
      case 'neutral':
        modifiedText = baseText;
        break;
    }

    setState(() {
      _responseController.text = modifiedText;
    });
  }
}
