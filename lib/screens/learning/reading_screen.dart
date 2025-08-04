import 'package:flutter/material.dart';

class ReadingScreen extends StatelessWidget {
  const ReadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView(
        children: [
          const SizedBox(height: 12),
          // Search bar with filter icon
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search for articles and readings...',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF0F0F0),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.filter_alt_outlined, color: Colors.black),
            ],
          ),
          const SizedBox(height: 24),

          // Continue Reading
          _sectionHeader("Continue Reading", onViewAll: () {}),
          _ebookCard(),

          const SizedBox(height: 24),
          // Popular Reads
          _sectionHeader("Popular Reads", onViewAll: () {}),
          _horizontalCards(),

          const SizedBox(height: 24),
          // Articles
          _sectionHeader("Articles", onViewAll: () {}),
          _horizontalCards(),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {required VoidCallback onViewAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          TextButton(onPressed: onViewAll, child: const Text("View All")),
        ],
      ),
    );
  }

  Widget _ebookCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('E-Book', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Emotional Intelligence in Communication',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const Text('by Fang Runin', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          const Text(
            '5 min read  •  Intermediate  •  80% complete',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
            child: const Text(
              "Continue Reading",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _horizontalCards() {
    return SizedBox(
      height: 220,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _readingCard(
            "Active Listening Techniques",
            "by Arlin Cuncic, MA",
            "3 min read",
            "Beginner",
          ),
          const SizedBox(width: 12),
          _readingCard(
            "Digital Communication: What It Is and Where It's Headed",
            "by Sana Ashraf",
            "6 min read",
            "Beginner",
          ),
        ],
      ),
    );
  }

  Widget _readingCard(
    String title,
    String author,
    String readTime,
    String level,
  ) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text("Article", style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(author, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Text('$readTime  •  $level', style: const TextStyle(fontSize: 12)),
          const Spacer(),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F55B2),
            ),
            child: const Text(
              "Read Now",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
