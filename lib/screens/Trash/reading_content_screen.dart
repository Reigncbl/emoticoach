import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ReadingContentScreen extends StatefulWidget {
  const ReadingContentScreen({super.key});

  @override
  State<ReadingContentScreen> createState() => _ReadingContentScreenState();
}

class _ReadingContentScreenState extends State<ReadingContentScreen> {
  late Future<List<Map<String, dynamic>>> _pageDataFuture;

  final String baseUrl = '${ApiConfig.baseUrl}/book/R-00002/24';

  @override
  void initState() {
    super.initState();
    _pageDataFuture = fetchReadingPage();
  }

  Future<List<Map<String, dynamic>>> fetchReadingPage() async {
    final response = await http.get(Uri.parse(baseUrl));

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.cast<Map<String, dynamic>>();
    } else {
      throw Exception("Failed to load page");
    }
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
            return const Center(child: Text("No content found."));
          }

          final blocks = snapshot.data!;

          return ListView.builder(
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
                    padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
                    child: Text(
                      content ?? '',
                      textAlign: _parseTextAlign(styleJson['align']),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: _parseFontWeight(styleJson['fontWeight']),
                        fontSize: (styleJson['fontSize'] as num?)?.toDouble(),
                      ),
                    ),
                  );

                case 'paragraph':
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      content ?? '',
                      textAlign: _parseTextAlign(styleJson['align']),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.6,
                        fontSize: (styleJson['fontSize'] as num?)?.toDouble(),
                        fontWeight: _parseFontWeight(styleJson['fontWeight']),
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
                      child: Image.network(
                        imageUrl, // Use the full URL from the backend
                        fit: BoxFit.fitWidth,
                        filterQuality: FilterQuality.high,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    size: 50,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Failed to load image',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );

                default:
                  return const SizedBox.shrink();
              }
            },
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
