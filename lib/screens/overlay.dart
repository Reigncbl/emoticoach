import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/colors.dart';
import '../controllers/suggestion_loader.dart';
import './emotion_analysis_loader.dart';
import '../utils/api_service.dart';
import 'package:emoticoach/screens/latest_message.dart' as latest_msg;
import 'package:emoticoach/screens/response.dart' as response;

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {
  int _selectedTab = 0; // 0=Emotion, 1=Response, 2=Tone

  // Contact details
  final String phone = "9615365763";
  final String firstName = "Carlo";
  final String lastName = "Lorieta";

  // State variables for filePath fetching
  String? _filePath;
  bool _isLoadingFilePath = true;
  String? _filePathError;
  final APIService _apiService = APIService();

  // State variables for analysis data
  Map<String, dynamic>? _analysisData;
  String? _analysisError;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      final response = await _apiService.fetchMessagesAndPath(
        phone,
        firstName,
        lastName,
      );
      if (mounted) {
        setState(() {
          _filePath = response['file_path'];
          // _isLoadingFilePath = false; // Moved to finally
        });
      }

      if (_filePath != null) {
        try {
          final analysisData = await _apiService.analyzeMessages(_filePath!);
          if (mounted) {
            setState(() {
              _analysisData = analysisData;
              _analysisError = null;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _analysisError = 'Error analyzing messages: $e';
              _analysisData = null;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _filePathError = e.toString();
          _filePath = null;
          _analysisData = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFilePath = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgCream,
      appBar: AppBar(
        title: const Text(
          'Chat Analysis',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
        elevation: 0,
        backgroundColor: kBgCream,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: _buildBodyContent(),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoadingFilePath) {
      return const Center(
        child: CircularProgressIndicator(key: ValueKey("filePathLoading")),
      );
    }
    if (_filePathError != null) {
      return Center(
        child: Text(
          'Error loading message data: $_filePathError',
          key: const ValueKey("filePathError"),
        ),
      );
    }
    // After file path checks, check for analysis error
    if (_analysisError != null) {
      return Center(
        child: Text(
          'Error loading analysis data: $_analysisError',
          key: const ValueKey("analysisError"),
        ),
      );
    }

    if (_filePath == null || _analysisData == null) {
      return const Center(
        child: Text(
          'File path or analysis data not available.',
          key: const ValueKey("dataNull"),
        ),
      );
    }

    // Tab content
    Widget tabContent;
    if (_selectedTab == 0) {
      tabContent = EmotionAnalysis(
        // filePath parameter removed
        analysisData: _analysisData!,
      );
    } else if (_selectedTab == 1) {
      tabContent = ChangeNotifierProvider(
        create: (_) => SuggestionLoader(),
        child: ResponseSuggestionScreen(
          messageFilePath: _filePath!, // Pass messageFilePath to suggestions
        ),
      );
    } else {
      tabContent = const Center(child: Text("Tone Adjuster Coming Soon!"));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Message from Carlo:",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        latest_msg.LatestMessageBox(
          // filePath parameter removed
          latestMessageText: _getLatestMessageText(),
        ),
        Row(
          children: [
            _TabButton(
              text: "Emotion\nAnalysis",
              selected: _selectedTab == 0,
              onTap: () => setState(() => _selectedTab = 0),
            ),
            _TabButton(
              text: "Response\nSuggestion",
              selected: _selectedTab == 1,
              onTap: () => setState(() => _selectedTab = 1),
            ),
            _TabButton(
              text: "Tone Adjuster",
              selected: _selectedTab == 2,
              onTap: () => setState(() => _selectedTab = 2),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(child: tabContent),
      ],
    );
  }

  String _getLatestMessageText() {
    try {
      // Safely access the nested data
      final results = _analysisData?['results'] as List?;
      if (results != null && results.isNotEmpty) {
        final firstResult = results.first as Map?;
        if (firstResult != null && firstResult.containsKey('text')) {
          return firstResult['text']?.toString() ??
              'No message text available.';
        }
      }
    } catch (e) {
      // Log error or handle appropriately
      print('Error extracting latest message: $e');
    }
    return 'Latest message not found.';
  }
}

class EmotionAnalysis extends StatelessWidget {
  // filePath field removed
  final Map<String, dynamic> analysisData;

  const EmotionAnalysis({
    super.key,
    // required this.filePath, // filePath field removed
    required this.analysisData,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: EmotionAnalysisLoader(
        // filePath parameter removed
        analysisData: analysisData,
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? Colors.blue : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

// Response suggestion screen
class ResponseSuggestionScreen extends StatefulWidget {
  final String messageFilePath; // Accept messageFilePath

  const ResponseSuggestionScreen({
    super.key,
    required this.messageFilePath, // Require messageFilePath in the constructor
  });

  @override
  State<ResponseSuggestionScreen> createState() =>
      _ResponseSuggestionScreenState();
}

class _ResponseSuggestionScreenState extends State<ResponseSuggestionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SuggestionLoader>(context, listen: false).loadSuggestions(
        messageFilePath: widget.messageFilePath,
      ); // Pass messageFilePath to loadSuggestions
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SuggestionLoader>(
      builder: (context, loader, child) {
        if (loader.isLoading && loader.suggestions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (loader.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('Error: ${loader.error}\n\nPlease try again.'),
            ),
          );
        }
        if (loader.suggestions.isEmpty) {
          return const Center(child: Text('No suggestions available.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: loader.suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = loader.suggestions[index];
            return response.ResponseSuggestionCard(
              title: 'Suggestion ${index + 1}',
              tone: suggestion['analysis']?.toString() ?? 'N/A',
              message: suggestion['suggestion']?.toString() ?? 'No message',
              onUse: () {
                // Add logic here for using a suggestion, e.g. copying to clipboard
              },
            );
          },
        );
      },
    );
  }
}
