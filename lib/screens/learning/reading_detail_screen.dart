import 'package:flutter/material.dart';
import '../../models/reading_model.dart';
import 'reading_content_screen.dart';
import '../../controllers/reading_content_controller.dart';
import '../../services/session_service.dart';
import 'epub_viewer.dart';

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
                        onTap: () {
                          // Pop back to previous screen (reading screen)
                          Navigator.pop(context, true); // Pass true to indicate data might have changed
                        },
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

  void _startReading(BuildContext context) async {
    try {
      // Check if this reading has an EPUB file and handle it directly
      if (reading.hasEpubFile) {
        print('Reading has EPUB file: ${reading.epubFilePath}');
        _startEpubReading(context);
        return;
      }
      
      // Get mobile number from session to fetch reading progress
      final mobileNumber = await SimpleSessionService.getUserPhone();
      int startingPage = 1; // Default to page 1
      
      if (mobileNumber != null && mobileNumber.isNotEmpty) {
        // Create a progress controller instance
        final progressController = ReadingProgressController();
        
        // Fetch the reading progress
        final progress = await progressController.fetchProgress(mobileNumber, reading.id);
        
        if (progress != null && progress.currentPage != null && progress.currentPage! > 0) {
          // If there's progress, start from the current page
          startingPage = progress.currentPage!;
          print('Found progress: starting from page $startingPage');
        } else {
          print('No progress found, starting from page 1');
        }
      } else {
        print('No mobile number available, starting from chapter 1');
      }
      
      // Navigate to reading content screen with the determined starting page
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReadingContentScreen(
            bookId: reading.id,
            startingPage: startingPage,
          ),
        ),
      );
      
      // If result is true, it means reading was completed or data changed
      if (result == true && context.mounted) {
        // Pop back to reading screen with indication that data changed
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error fetching reading progress: $e');
      // If there's an error, just start from page 1
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReadingContentScreen(
            bookId: reading.id,
            startingPage: 1,
          ),
        ),
      );
      
      // If result is true, it means reading was completed or data changed
      if (result == true && context.mounted) {
        // Pop back to reading screen with indication that data changed
        Navigator.pop(context, true);
      }
    }
  }

  // Helper to load epub bytes from assets (local file)
  Future<List<int>> _loadEpubBytes(BuildContext context, String assetPath) async {
    try {
      print('Attempting to load EPUB from path: $assetPath');
      
      // Use rootBundle to load asset as bytes
      final byteData = await DefaultAssetBundle.of(context).load(assetPath);
      final bytes = byteData.buffer.asUint8List();
      
      print('Successfully loaded EPUB file. Size: ${bytes.length} bytes');
      return bytes;
    } catch (e) {
      print('Error loading EPUB asset: $e');
      throw Exception('Failed to load EPUB file: $e');
    }
  }

  // Start EPUB reading directly
  void _startEpubReading(BuildContext context) async {
    try {
      print('Starting EPUB reading for: ${reading.title}');
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Load EPUB bytes
      final bytes = await _loadEpubBytes(context, reading.epubFilePath!);
      
      // Close loading dialog
      if (context.mounted) Navigator.of(context).pop();
      
      // Navigate to EPUB viewer
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EpubViewer(
            epubBytes: bytes,
            bookId: reading.id,
            title: reading.title,
          ),
        ),
      );
      
      // If result is true, it means reading was completed or data changed
      if (result == true && context.mounted) {
        // Show completion message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Reading completed! Well done!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Always pop back to reading screen with indication that data changed
      if (context.mounted) {
        Navigator.pop(context, true);
      }
      
    } catch (e) {
      print('Error loading EPUB: $e');
      
      // Close loading dialog if still open
      if (context.mounted) Navigator.of(context).pop();
      
      // Show error dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error Loading EPUB'),
            content: Text('Failed to load the EPUB file: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
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

// TRY ========================
class ReadingProgressBox extends StatefulWidget {
  final String readingsId;
  final ReadingProgressController controller;

  const ReadingProgressBox({
    Key? key,
    required this.readingsId,
    required this.controller,
  }) : super(key: key);

  @override
  _ReadingProgressBoxState createState() => _ReadingProgressBoxState();
}

class _ReadingProgressBoxState extends State<ReadingProgressBox> {
  ReadingProgress? progress;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadProgress();
  }

  Future<void> loadProgress() async {
    try {
      // Get mobile number from session
      String? mobileNumber = await SimpleSessionService.getUserPhone();
      
      if (mobileNumber == null || mobileNumber.isEmpty) {
        setState(() {
          error = "Mobile number not available";
          isLoading = false;
        });
        return;
      }

      final result = await widget.controller.fetchProgress(mobileNumber, widget.readingsId);
      setState(() {
        progress = result;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Text("Error: $error", style: const TextStyle(color: Colors.red))
              : progress == null
                  ? const Text("No progress found")
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reading ID: ${progress!.readingsId}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('Current Page: ${progress!.currentPage ?? "N/A"}'),
                        Text('Last Read At: ${progress!.lastReadAt ?? "N/A"}'),
                        Text('Completed At: ${progress!.completedAt ?? "N/A"}'),
                      ],
                    ),
    );
  }
}