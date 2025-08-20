import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ReadingContentScreen extends StatefulWidget {
  final String? bookId;
  final String? pageId;

  const ReadingContentScreen({super.key, this.bookId, this.pageId});

  @override
  State<ReadingContentScreen> createState() => _ReadingContentScreenState();
}

class _ReadingContentScreenState extends State<ReadingContentScreen> {
  late int _currentPage;
  late Future<List<Map<String, dynamic>>> _pageDataFuture;

  @override
  void initState() {
    super.initState();
    _currentPage = int.tryParse(widget.pageId ?? '1') ?? 1;
    _pageDataFuture = fetchReadingPage();
  }

  String get baseUrl {
    final bookId = widget.bookId ?? 'R-00002';
    return 'http://10.0.2.2:8000/book/$bookId/$_currentPage';
  }

  Future<List<Map<String, dynamic>>> fetchReadingPage() async {
    final response = await http.get(Uri.parse(baseUrl));
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);

      if (jsonList.isEmpty) {
        // Delay navigation until after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ReadingCompletionScreen()),
          );
        });
      }

      return jsonList.cast<Map<String, dynamic>>();
    } else {
      throw Exception("Failed to load page");
    }
  }

  void _nextPage() {
    setState(() {
      _currentPage++;
      _pageDataFuture = fetchReadingPage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reading Module")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _pageDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox.shrink();
          }

          final blocks = snapshot.data!;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: blocks.length,
                  itemBuilder: (context, index) {
                    final block = blocks[index];
                    final type = block['blocktype']?.toString() ?? '';
                    final content = block['content']?.toString();
                    final imageUrl = block['imageurl']?.toString();
                    final styleJson = _parseStyleJson(block['stylejson']);

                    switch (type) {
                      case 'heading':
                        return Padding(
                          padding: const EdgeInsets.only(
                            top: 24.0,
                            bottom: 8.0,
                          ),
                          child: Text(
                            content ?? '',
                            textAlign: _parseTextAlign(styleJson['align']),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: _parseFontWeight(
                                    styleJson['fontWeight'],
                                  ),
                                  fontSize: (styleJson['fontSize'] as num?)
                                      ?.toDouble(),
                                ),
                          ),
                        );
                      case 'paragraph':
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Text(
                            content ?? '',
                            textAlign: _parseTextAlign(styleJson['align']),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  height: 1.6,
                                  fontSize: (styleJson['fontSize'] as num?)
                                      ?.toDouble(),
                                  fontWeight: _parseFontWeight(
                                    styleJson['fontWeight'],
                                  ),
                                ),
                          ),
                        );
                      case 'image':
                        if (imageUrl == null || imageUrl.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(imageUrl),
                          ),
                        );
                      default:
                        return const SizedBox.shrink();
                    }
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  onPressed: _nextPage,
                  child: const Text("Next Page"),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Map<String, dynamic> _parseStyleJson(dynamic jsonString) {
    if (jsonString == null) return {};
    try {
      if (jsonString is String && jsonString.isNotEmpty) {
        return json.decode(jsonString);
      }
    } catch (_) {}
    return {};
  }

  TextAlign _parseTextAlign(String? value) {
    switch (value?.toLowerCase()) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      default:
        return TextAlign.left;
    }
  }

  FontWeight _parseFontWeight(String? value) {
    switch (value?.toLowerCase()) {
      case 'bold':
        return FontWeight.bold;
      case 'w500':
        return FontWeight.w500;
      case 'w300':
        return FontWeight.w300;
      default:
        return FontWeight.normal;
    }
  }
}

class ReadingCompletionScreen extends StatelessWidget {
  const ReadingCompletionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Completed")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              "Congratulations!\nYou've completed this reading.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Back to Modules"),
            ),
          ],
        ),
      ),
    );
  }
}
