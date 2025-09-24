import 'package:flutter/material.dart';
import '../../models/reading_model.dart';
import '../../utils/colors.dart';

class ReadingCard extends StatelessWidget {
  final Reading reading;
  final VoidCallback? onTap;
  final bool isContinueReading; // New parameter to indicate if this is in continue reading section

  const ReadingCard({
    super.key, 
    required this.reading, 
    this.onTap,
    this.isContinueReading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getCategoryColor(reading.category),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                reading.category,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Title
            Text(
              reading.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Author
            Text(
              reading.author,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 6),

            // Duration and difficulty
            Text(
              '${reading.formattedDuration} • ${reading.difficulty}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),

            // Rating and XP
            Row(
              children: [
                Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                const SizedBox(width: 2),
                Text(
                  reading.rating.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 12),
                ),
                const Spacer(),
                Text(
                  '${reading.xpPoints} XP',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Progress bar
            if (reading.progress > 0) ...[
              LinearProgressIndicator(
                value: reading.progress,
                backgroundColor: Colors.grey.shade300,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 4),
              Text(
                reading.progressPercentage + ' complete',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],

            const Spacer(),

            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: reading.progress > 0
                      ? Colors.deepOrange
                      : kBrightBlue,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  reading.isCompleted
                      ? "Read Again"
                      : (isContinueReading ? "Continue Reading" 
                         : (reading.progress > 0 ? "Continue" : "Read Now")),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'article':
        return Colors.blue.shade100;
      case 'e-book':
      case 'ebook':
        return Colors.orange.shade100;
      case 'guide':
        return Colors.green.shade100;
      case 'research':
        return Colors.purple.shade100;
      default:
        return Colors.grey.shade100;
    }
  }
}
