import 'package:flutter/material.dart';
import '../utils/colors.dart';

// Shared AppBar for book/EPUB readers
class BookReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title; // Book title (main title)
  final int? currentPage;
  final int? totalPages;
  final VoidCallback? onBackPressed;

  const BookReaderAppBar({
    super.key,
    required this.title,
    this.currentPage,
    this.totalPages,
    this.onBackPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 24),
        onPressed: onBackPressed ?? () => Navigator.pop(context),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class NextChapterWidget extends StatelessWidget {
  final VoidCallback? onTap;
  final String text;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final int currentPage;
  final int totalPages;

  const NextChapterWidget({
    super.key,
    this.onTap,
    this.text = 'Next Chapter',
    this.showBackButton = false,
    this.onBackPressed,
    this.currentPage = 1,
    this.totalPages = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0, bottom: 12.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Page $currentPage of $totalPages',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: kBrightOrange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.menu,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                if (showBackButton) ...[
                  SizedBox(
                    width: 80,
                    height: 48,
                    child: TextButton(
                      onPressed: onBackPressed,
                      style: TextButton.styleFrom(
                        backgroundColor: kLightGrey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Back',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: GestureDetector(
                    onTap: onTap,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: kBrightOrange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MinimalAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MinimalAppBar({super.key});
  @override
  Size get preferredSize => const Size.fromHeight(36);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Container(color: Colors.white),
    );
  }
}

class MinimalFooter extends StatelessWidget {
  final double progressPercent;
  const MinimalFooter({super.key, required this.progressPercent});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Center(
        child: Text(
          '${(progressPercent * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class PageStatusFooter extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final double progressPercent;
  final VoidCallback? onCompleteReading; // New callback for completion
  
  const PageStatusFooter({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.progressPercent,
    this.onCompleteReading,
  });
  
  @override
  Widget build(BuildContext context) {
    // Check if we're on the last page (or close to the end)
    final bool isNearEnd = currentPage >= totalPages || progressPercent >= 0.95;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Page $currentPage of $totalPages',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(progressPercent * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          // Show Complete Reading button when near the end
          if (isNearEnd && onCompleteReading != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: onCompleteReading,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBrightOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Complete Reading',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
