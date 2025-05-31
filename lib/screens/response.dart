import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/suggestion_loader.dart'; // Adjust path if needed

// ResponseSuggestionCard Widget (remains in the same file)
class ResponseSuggestionCard extends StatelessWidget {
  final String title;
  final String tone;
  final String message;
  final VoidCallback onUse;

  const ResponseSuggestionCard({
    super.key,
    required this.title,
    required this.tone,
    required this.message,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              'Tone: $tone',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8.0),
            Text(message),
            const SizedBox(height: 16.0),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: onUse,
                child: const Text('Use this'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ResponseScreen StatefulWidget
class ResponseScreen extends StatefulWidget {
  final String phone;
  final String firstName;
  final String lastName;

  const ResponseScreen({
    super.key,
    required this.phone,
    required this.firstName,
    required this.lastName,
  });

  @override
  State<ResponseScreen> createState() => _ResponseScreenState();
}

class _ResponseScreenState extends State<ResponseScreen> {
  @override
  void initState() {
    super.initState();
    // Use a post-frame callback to ensure the context is available
    // and to safely interact with Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final suggestionLoader = Provider.of<SuggestionLoader>(
        context,
        listen: false,
      );
      suggestionLoader.loadSuggestions(
        widget.phone,
        widget.firstName,
        widget.lastName,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // It's generally better to provide SuggestionLoader at a higher level in the widget tree
    // if it's used by multiple screens. If it's only for this screen,
    // providing it here is fine.
    return ChangeNotifierProvider(
      create: (_) => SuggestionLoader(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Response Suggestions')),
        body: Consumer<SuggestionLoader>(
          builder: (context, loader, child) {
            if (loader.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (loader.error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error: ${loader.error}'),
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
                return ResponseSuggestionCard(
                  title: 'Suggestion ${index + 1}',
                  tone: suggestion['analysis']?.toString() ?? 'N/A',
                  message: suggestion['suggestion']?.toString() ?? 'No message',
                  onUse: () {
                    // Handle "Use this" action
                    print('Using suggestion: ${suggestion['suggestion']}');
                    // Example: Copy to clipboard
                    // Clipboard.setData(ClipboardData(text: suggestion['suggestion']?.toString() ?? ''));
                    // ScaffoldMessenger.of(context).showSnackBar(
                    //   const SnackBar(content: Text('Suggestion copied to clipboard!')),
                    // );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
