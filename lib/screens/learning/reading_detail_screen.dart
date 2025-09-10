import 'package:flutter/material.dart';
import '../../models/reading_model.dart';
import 'reading_content_screen.dart';

class ReadingDetailScreen extends StatelessWidget {
  final Reading reading;

  const ReadingDetailScreen({super.key, required this.reading});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Gradient Header with Stats Inside
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0026E3), Color(0xFF2582FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        "Article",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    reading.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "by ${reading.author}",
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    reading.difficulty,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stat boxes now inside gradient
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatCard(
                        value: "${reading.xpPoints}",
                        label: "XP Points",
                        color: Colors.white.withOpacity(0.15),
                        textColor: Colors.white,
                      ),
                      _buildStatCard(
                        value: reading.formattedRating,
                        label: "Rating",
                        color: Colors.white.withOpacity(0.15),
                        textColor: Colors.white,
                      ),
                      _buildStatCard(
                        value: reading.formattedDuration,
                        label: "Minutes",
                        color: Colors.white.withOpacity(0.15),
                        textColor: Colors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Synopsis Section
                    const Text(
                      'Synopsis',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This article outlines the concept of active listening—fully focusing, understanding, and responding to a speaker. It highlights seven key techniques such as maintaining eye contact, asking open-ended questions, and reflecting what you hear to improve communication and build stronger relationships.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Rate This Module Section
                    const Text(
                      'Rate This Module',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // 5 Star Rating
                        Row(
                          children: List.generate(5, (index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.star_border,
                                color: Colors.grey.shade400,
                                size: 28,
                              ),
                            );
                          }),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () {
                            // Handle rating action
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Rating feature coming soon!'),
                              ),
                            );
                          },
                          child: const Text(
                            'Rate',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF2582FF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Skills You'll Learn Section
                    const Text(
                      'Skills You\'ll Learn',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: [
                        _buildSkillChip('Active Listening'),
                        const SizedBox(height: 8),
                        _buildSkillChip('Empathetic Response'),
                        const SizedBox(height: 8),
                        _buildSkillChip('Reflective communication'),
                      ],
                    ),
                    const SizedBox(
                      height: 40,
                    ), // Extra space before the bottom button
                  ],
                ),
              ),
            ),

            // Fixed button at bottom
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _startReading(context),
                      label: Text(
                        reading.progress > 0
                            ? 'Continue Reading'
                            : 'Start Reading',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: reading.progress > 0
                            ? Colors.deepOrange
                            : const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startReading(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReadingContentScreen(
          bookId: reading.id,
          pageId: '1', // or whatever default page
        ),
      ),
    );
  }
}

Widget _buildStatCard({
  required String value,
  required String label,
  required Color color,
  required Color textColor,
}) {
  return Expanded(
    child: Container(
      padding: EdgeInsets.symmetric(vertical: 4),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      // Make it square by setting a fixed aspect ratio
      child: AspectRatio(
        aspectRatio: 1.5, // This makes it square
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor.withOpacity(0.8),
                fontWeight: FontWeight.w400,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildSkillChip(String skill) {
  return Align(
    alignment: Alignment.centerLeft, // align left
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFF3B82F6)),
      ),
      child: Text(
        skill,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    ),
  );
}
