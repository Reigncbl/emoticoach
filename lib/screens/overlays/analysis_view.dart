import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:emoticoach/services/api_service.dart';
import 'package:emoticoach/utils/colors.dart';
import 'package:emoticoach/utils/overlay_stats_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalysisView extends StatefulWidget {
  final String selectedContact;
  final String contactPhone;
  final String userPhoneNumber;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onBackToContacts;

  const AnalysisView({
    super.key,
    required this.selectedContact,
    required this.contactPhone,
    required this.userPhoneNumber,
    required this.onClose,
    required this.onEdit,
    required this.onBackToContacts,
  });

  @override
  State<AnalysisView> createState() => _AnalysisViewState();
}

class _AnalysisViewState extends State<AnalysisView> {
  final APIService _apiService = APIService();
  bool _isLoading = true;
  String _errorMessage = '';
  String _latestMessage = '';

  // Emotion analysis state
  bool _isAnalyzing = false;
  Map<String, dynamic>? _emotionAnalysis;
  String _analysisError = '';

  // Toggle settings from overlay page
  bool _messageAnalysisEnabled = false;
  bool _smartSuggestionsEnabled = false;
  bool _toneAdjusterEnabled = false;
  bool _settingsLoaded = false; // Track if settings are loaded
  Timer? _settingsTimer; // Timer for periodic settings check

  // Preference keys (matching overlay_page.dart)
  static const String _messageAnalysisKey = 'message_analysis_enabled';
  static const String _smartSuggestionsKey = 'smart_suggestions_enabled';
  static const String _toneAdjusterKey = 'tone_adjuster_enabled';

  @override
  void initState() {
    super.initState();
    _initializeView();
  }

  @override
  void didUpdateWidget(AnalysisView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload settings when widget updates
    _loadSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload settings when dependencies change
    _loadSettings();
  }

  // Add a method to check for setting changes periodically
  void _startPeriodicSettingsCheck() {
    _settingsTimer?.cancel(); // Cancel any existing timer
    _settingsTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      if (mounted) {
        _checkAndUpdateSettings();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _settingsTimer?.cancel(); // Clean up timer
    super.dispose();
  }

  Future<void> _checkAndUpdateSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newAnalysis = prefs.getBool(_messageAnalysisKey) ?? false;
      final newSuggestions = prefs.getBool(_smartSuggestionsKey) ?? false;
      final newTone = prefs.getBool(_toneAdjusterKey) ?? false;

      // Only update if something changed
      if (newAnalysis != _messageAnalysisEnabled ||
          newSuggestions != _smartSuggestionsEnabled ||
          newTone != _toneAdjusterEnabled) {
        print('🔄 Settings changed detected! Updating UI...');
        print('  Analysis: $_messageAnalysisEnabled -> $newAnalysis');
        print('  Suggestions: $_smartSuggestionsEnabled -> $newSuggestions');
        print('  Tone: $_toneAdjusterEnabled -> $newTone');

        setState(() {
          _messageAnalysisEnabled = newAnalysis;
          _smartSuggestionsEnabled = newSuggestions;
          _toneAdjusterEnabled = newTone;
        });
      }
    } catch (e) {
      print('❌ Error checking settings: $e');
    }
  }

  Future<void> _initializeView() async {
    await _loadSettings();
    _fetchMessages();
    _startPeriodicSettingsCheck(); // Start checking for changes
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _messageAnalysisEnabled = prefs.getBool(_messageAnalysisKey) ?? false;
        _smartSuggestionsEnabled = prefs.getBool(_smartSuggestionsKey) ?? false;
        _toneAdjusterEnabled = prefs.getBool(_toneAdjusterKey) ?? false;
        _settingsLoaded = true; // Mark settings as loaded
      });
      print(
        '✅ Analysis view settings loaded - Analysis: $_messageAnalysisEnabled, Suggestions: $_smartSuggestionsEnabled, Tone: $_toneAdjusterEnabled',
      );
    } catch (e) {
      print('❌ Error loading analysis view settings: $e');
      setState(() {
        _settingsLoaded = true; // Still mark as loaded to show UI
      });
    }
  }

  Future<void> _fetchMessages() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
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

        // Perform emotion analysis on the latest message
        if (latestMessage.isNotEmpty &&
            latestMessage != 'No recent messages found') {
          _analyzeEmotion(latestMessage);
        }
      } else {
        setState(() {
          _isLoading = false;
          if (response['auth_required'] == true) {
            _errorMessage =
                'Telegram authentication required. Please re-authenticate in the profile settings.';
          } else {
            _errorMessage = response['error'] ?? 'Failed to load messages';
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading messages: $e';
      });
    }
  }

  String _getLatestContactMessage(List<dynamic> messages) {
    // Debug print to see the message structure
    print('DEBUG: Processing ${messages.length} messages');
    print('DEBUG: Contact name: ${widget.selectedContact}');

    // The messages are already ordered from newest to oldest
    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      print('DEBUG: Message $i: $message');

      // Get the sender name
      final from = message['from']?.toString() ?? '';
      final messageText = message['text']?.toString() ?? '';

      // Check if this message is from the contact (not from "reign" which is the user)
      final isFromContact =
          from.toLowerCase() != '' &&
          from.toLowerCase() != widget.userPhoneNumber.replaceAll('+', '') &&
          messageText.isNotEmpty;

      if (isFromContact) {
        print('DEBUG: Found latest message from contact ($from): $messageText');
        return messageText;
      }
    }
    return 'No recent messages found';
  }

  Future<void> _analyzeEmotion(String text) async {
    try {
      setState(() {
        _isAnalyzing = true;
        _analysisError = '';
      });

      final analysisResponse = await _apiService.analyzeText(text);

      if (analysisResponse['success'] == true) {
        setState(() {
          _emotionAnalysis = analysisResponse['data'];
          _isAnalyzing = false;
        });

        // Track successful message analysis
        await OverlayStatsTracker.trackMessageAnalyzed(
          messageContent: text,
          analysisType: 'emotion_analysis',
          sessionId: 'analysis_${DateTime.now().millisecondsSinceEpoch}',
        );

        print('✅ Tracked message analysis event');
      } else {
        setState(() {
          _analysisError =
              analysisResponse['error'] ?? 'Failed to analyze emotion';
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _analysisError = 'Error analyzing emotion: $e';
      });
    }
  }

  void _showCopyFeedbackDialog(String message, Color backgroundColor) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        // Auto-dismiss after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  backgroundColor == Colors.green ? Icons.check : Icons.error,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final containerWidth = screenWidth;
    final maxWidth = 600.0;
    final finalWidth = containerWidth > maxWidth ? maxWidth : containerWidth;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
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
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: [_buildHeader(), _buildContent()]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            child: Row(
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
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _openTutorial,
                  icon: const Icon(Icons.info, color: kPrimaryBlue, size: 22),
                  tooltip: 'Analysis screen tutorial',
                ),
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(2),
                    child: const Icon(
                      Icons.close,
                      color: kPrimaryBlue,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildMessageBubble(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading || !_settingsLoaded)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          _isLoading
                              ? 'Loading messages...'
                              : 'Loading settings...',
                        ),
                      ],
                    ),
                  ),
                )
              else if (_errorMessage.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red),
                        SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchMessages,
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Debug: Show current toggle states
                if (const bool.fromEnvironment('dart.vm.product') == false)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      border: Border.all(color: Colors.orange[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '🛠️ Debug: Toggle States',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                                fontSize: 12,
                              ),
                            ),
                            Spacer(),
                            GestureDetector(
                              onTap: () async {
                                print('🔄 Manually refreshing settings...');
                                await _loadSettings();
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '🔄 Refresh',
                                  style: TextStyle(
                                    color: Colors.orange[800],
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Analysis: $_messageAnalysisEnabled | Suggestions: $_smartSuggestionsEnabled | Tone: $_toneAdjusterEnabled',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Show sections based on toggle settings
                if (_messageAnalysisEnabled) ...[
                  _buildToneSection(),
                  const SizedBox(height: 10),
                  _buildInterpretationSection(),
                  const SizedBox(height: 10),
                ],
                if (_smartSuggestionsEnabled) ...[
                  _buildSuggestedResponseSection(),
                  const SizedBox(height: 10),
                ],
                if (_toneAdjusterEnabled) ...[_buildChecklist()],
                // Show a message if no features are enabled
                if (!_messageAnalysisEnabled &&
                    !_smartSuggestionsEnabled &&
                    !_toneAdjusterEnabled)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.settings, size: 48, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No analysis features enabled',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Enable Message Analysis, Smart Suggestions, or Tone Adjuster in the overlay settings to see analysis results.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble() {
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
                GestureDetector(
                  onTap: widget.onBackToContacts,
                  child: Container(
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
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
            Text(
              _latestMessage.isNotEmpty
                  ? '"$_latestMessage"'
                  : 'No message available',
              style: const TextStyle(
                color: kWhite,
                fontSize: 13,
                fontStyle: FontStyle.normal,
              ),
              // textAlign: TextAlign.justify,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToneSection() {
    return _buildSection(
      icon: '🔍',
      title: 'Detected Tone',
      content: _getToneForContact(widget.selectedContact),
    );
  }

  Widget _buildInterpretationSection() {
    return _buildSection(
      icon: '📝',
      title: 'Interpretation',
      content: _getInterpretationForContact(widget.selectedContact),
    );
  }

  Widget _buildSuggestedResponseSection() {
    final responseText = _getSuggestedResponseForContact(
      widget.selectedContact,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '💡 Suggested Response',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                responseText,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                contextMenuBuilder:
                    (
                      BuildContext context,
                      EditableTextState editableTextState,
                    ) {
                      return AdaptiveTextSelectionToolbar(
                        anchors: editableTextState.contextMenuAnchors,
                        children: [
                          TextSelectionToolbarTextButton(
                            padding: const EdgeInsets.all(8.0),
                            onPressed: () {
                              editableTextState.copySelection(
                                SelectionChangedCause.toolbar,
                              );
                              editableTextState.hideToolbar();
                            },
                            child: const Text('Copy'),
                          ),
                          TextSelectionToolbarTextButton(
                            padding: const EdgeInsets.all(8.0),
                            onPressed: () {
                              editableTextState.selectAll(
                                SelectionChangedCause.toolbar,
                              );
                              editableTextState.hideToolbar();
                            },
                            child: const Text('Select All'),
                          ),
                        ],
                      );
                    },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildActionButton(
                    icon: Icons.check_circle_outline,
                    label: 'Use',
                    color: Colors.blue,
                    onTap: () async {
                      try {
                        final suggestedResponse =
                            _getSuggestedResponseForContact(
                              widget.selectedContact,
                            );
                        await Clipboard.setData(
                          ClipboardData(text: suggestedResponse),
                        );

                        // Track suggestion usage
                        await OverlayStatsTracker.trackSuggestionUsed(
                          suggestionType: 'ai_generated_response',
                          originalMessage: _latestMessage,
                          suggestedMessage: suggestedResponse,
                          sessionId:
                              'analysis_${DateTime.now().millisecondsSinceEpoch}',
                        );

                        _showCopyFeedbackDialog(
                          'Copied to clipboard!',
                          Colors.green,
                        );

                        print('✅ Tracked suggestion usage event');
                      } catch (e) {
                        _showCopyFeedbackDialog(
                          'Failed to copy to clipboard',
                          Colors.red,
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  _buildActionButton(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    color: Colors.blue,
                    onTap: () async {
                      // Track response rephrasing intent
                      await OverlayStatsTracker.trackResponseRephrased(
                        originalText: _getSuggestedResponseForContact(
                          widget.selectedContact,
                        ),
                        toneAdjustment: 'user_edit_requested',
                        sessionId:
                            'analysis_${DateTime.now().millisecondsSinceEpoch}',
                      );

                      print('✅ Tracked response rephrasing event');

                      // Call the original edit callback
                      widget.onEdit();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChecklist() {
    return Container(
      child: Text(
        _getChecklistForContact(widget.selectedContact),
        style: const TextStyle(color: Colors.blue, fontSize: 11, height: 1.3),
      ),
    );
  }

  Widget _buildSection({
    required String icon,
    required String title,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$icon $title',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          content,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 12,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _getToneForContact(String contact) {
    if (_isAnalyzing) {
      return 'Analyzing...';
    }

    if (_analysisError.isNotEmpty) {
      return 'Analysis failed';
    }

    if (_emotionAnalysis != null) {
      final emotion = _emotionAnalysis!['emotion'];
      final confidence = _emotionAnalysis!['confidence'];
      final emoji = _emotionAnalysis!['emoji'];

      if (emotion != null && confidence != null) {
        String result = '${emotion[0].toUpperCase()}${emotion.substring(1)}';
        result += ' (${(confidence * 100).toInt()}% confidence)';

        if (emoji != null) {
          result += ' $emoji';
        }

        return result;
      }
    }

    // Fallback to hardcoded values for testing
    switch (contact) {
      case 'Carlo Lorieta':
        return 'Casual & Playful';
      case 'Maria Santos':
        return 'Grateful & Friendly';
      case 'John Dela Cruz':
        return 'Professional & Brief';
      case 'Sarah Kim':
        return 'Encouraging & Positive';
      default:
        return 'Neutral';
    }
  }

  String _getInterpretationForContact(String contact) {
    if (_isAnalyzing) {
      return 'Analyzing message context...';
    }

    if (_analysisError.isNotEmpty) {
      return 'Unable to analyze interpretation: $_analysisError';
    }

    if (_emotionAnalysis != null) {
      // Access the nested analysis structure from your response
      final analysis = _emotionAnalysis!['analysis'];
      if (analysis != null && analysis['analysis'] != null) {
        final analysisData = analysis['analysis'];
        final primaryEmotion = analysisData['primary_emotion'];
        final interpretation = analysisData['interpretation'];

        if (interpretation != null) {
          String result = interpretation;

          // Add primary emotion context if available
          if (primaryEmotion != null) {
            result += '\n\nPrimary emotion: $primaryEmotion';
          }

          return result;
        }
      }
    }

    // Fallback to hardcoded values for testing
    switch (contact) {
      case 'Carlo Lorieta':
        return 'Carlo seems to be keeping the mood light and understanding. He\'s probably saying it\'s okay to drop the topic.';
      case 'Maria Santos':
        return 'Maria is expressing genuine gratitude and wants to maintain a positive relationship.';
      case 'John Dela Cruz':
        return 'John is being direct and professional, focusing on the next meeting.';
      case 'Sarah Kim':
        return 'Sarah is giving positive feedback and encouragement for your work.';
      default:
        return 'The message appears to be neutral in tone.';
    }
  }

  String _getSuggestedResponseForContact(String contact) {
    if (_isAnalyzing) {
      return 'Generating personalized response...';
    }

    if (_analysisError.isNotEmpty) {
      return 'Unable to generate suggestion. Please try again.';
    }

    if (_emotionAnalysis != null) {
      // Access the coaching section from your response structure
      final analysis = _emotionAnalysis!['analysis'];
      if (analysis != null && analysis['coaching'] != null) {
        final coaching = analysis['coaching'];

        // Use suggested_response first
        final suggestedResponse = coaching['suggested_response'];
        if (suggestedResponse != null && suggestedResponse.isNotEmpty) {
          return suggestedResponse;
        }

        // Fallback to empathetic_statement if suggested_response is not available
        final empathetic = coaching['empathetic_statement'];
        if (empathetic != null && empathetic.isNotEmpty) {
          return empathetic;
        }

        // If neither, try first suggestion
        final suggestions = coaching['suggestions'];
        if (suggestions != null &&
            suggestions is List &&
            suggestions.isNotEmpty) {
          return suggestions.first.toString();
        }
      }
    }

    // Fallback to hardcoded values for testing
    switch (contact) {
      case 'Carlo Lorieta':
        return 'Thank you po for understanding! Wishing you and the team all the best din 🫶';
      case 'Maria Santos':
        return 'You\'re very welcome! Happy to help anytime 😊';
      case 'John Dela Cruz':
        return 'Looking forward to it! See you there.';
      case 'Sarah Kim':
        return 'Thank you so much! I really appreciate your kind words 🙏';
      default:
        return 'Thank you for your message!';
    }
  }

  String _getChecklistForContact(String contact) {
    switch (contact) {
      case 'Carlo':
        return '✓ Keeps things friendly\n✓ Acknowledges his tone\n✓ Closes the convo on a good note';
      case 'Maria Santos':
        return '✓ Acknowledges gratitude\n✓ Maintains warm tone\n✓ Offers future help';
      case 'John Dela Cruz':
        return '✓ Professional response\n✓ Confirms attendance\n✓ Brief and appropriate';
      case 'Sarah Kim':
        return '✓ Shows appreciation\n✓ Humble response\n✓ Positive engagement';
      default:
        return '✓ Appropriate response\n✓ Maintains tone\n✓ Clear communication';
    }
  }

  void _openTutorial() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return _buildTutorialDialog();
      },
    );
  }

  Widget _buildTutorialDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              spreadRadius: 3,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title section
            Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/AI-Chat-nav.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    kPrimaryBlue,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Analysis Screen Guide',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Content section
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTutorialSection(
                    icon: Icons.psychology,
                    title: 'Emotion Analysis',
                    description:
                        'View the detected emotional tone and confidence level of the latest message from your contact.',
                  ),
                  const SizedBox(height: 16),
                  _buildTutorialSection(
                    icon: Icons.lightbulb_outline,
                    title: 'Smart Interpretation',
                    description:
                        'Get AI-powered insights about what your contact might be feeling or trying to communicate.',
                  ),
                  const SizedBox(height: 16),
                  _buildTutorialSection(
                    icon: Icons.chat_bubble_outline,
                    title: 'Suggested Response',
                    description:
                        'Receive personalized response suggestions that match the tone and context of the conversation.',
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'The analysis is based on the most recent message from your contact.',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Actions section
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Got it!',
                  style: TextStyle(
                    color: kPrimaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorialSection({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kPrimaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: kPrimaryBlue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
