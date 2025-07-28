import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class ReadingContentScreen extends StatefulWidget {
  const ReadingContentScreen({super.key});

  @override
  State<ReadingContentScreen> createState() => _ReadingContentScreenState();
}

class _ReadingContentScreenState extends State<ReadingContentScreen> {
  late Future<Map<int, List<Map<String, dynamic>>>> _pagesFuture;

  @override
  void initState() {
    super.initState();
    _pagesFuture = loadAndGroupByPage();
  }

  Future<Map<int, List<Map<String, dynamic>>>> loadAndGroupByPage() async {
    final data = await rootBundle.loadString('assets/sample.json');
    final blocks = List<Map<String, dynamic>>.from(json.decode(data));

    final Map<int, List<Map<String, dynamic>>> pages = {};
    for (var block in blocks) {
      final content = block['Content']?.toString() ?? '';
      final imageUrl = block['ImageURL']?.toString() ?? '';

      if (content.trim().isNotEmpty || imageUrl.trim().isNotEmpty) {
        final page = block['PageNumber'] ?? 0;
        pages.putIfAbsent(page, () => []).add(block);
      }
    }

    return pages;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reading Module")),
      body: FutureBuilder<Map<int, List<Map<String, dynamic>>>>(
        future: _pagesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No content found."));
          }

          final pageKeys = snapshot.data!.keys.toList()..sort();
          final pages = snapshot.data!;

          return PageView.builder(
            itemCount: pageKeys.length,
            itemBuilder: (context, pageIndex) {
              final pageNumber = pageKeys[pageIndex];
              final blocks = pages[pageNumber]!;

              return Padding(
                padding: const EdgeInsets.all(16),
                child: ListView.builder(
                  itemCount: blocks.length,
                  itemBuilder: (context, index) {
                    final block = blocks[index];
                    final type = block['BlockType']?.toString() ?? '';
                    final content = block['Content']?.toString();
                    final imageUrl = block['ImageURL']?.toString();
                    final styleJson = _parseStyleJson(block['StyleJSON']);

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
                        final filename = imageUrl.split('/').last;
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/output_images/$filename',
                            fit: BoxFit.fitWidth,
                            filterQuality: FilterQuality.high,
                          ),
                        );

                      default:
                        return const SizedBox.shrink();
                    }
                  },
                ),
              );
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
