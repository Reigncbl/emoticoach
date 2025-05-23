import 'package:flutter/material.dart';
import '../utils/colors.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgCream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Good morning, John Paul!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Icon(Icons.notifications_outlined, color: Colors.grey[700]),
                ],
              ),
              const SizedBox(height: 18),

              // Quote of the Day Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: kQuoteBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.format_quote, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Quote of the Day',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"The single biggest problem in communication is the illusion that it has taken place."',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        '— George Bernard Shaw',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Daily Challenge Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: kDailyChallengeBg,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.03),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: kDailyChallengeRed.withOpacity(0.15),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flag, color: kDailyChallengeRed),
                        const SizedBox(width: 8),
                        Text(
                          'Daily Challenge',
                          style: TextStyle(
                            color: kDailyChallengeRed,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ask someone about their day and really listen to their response without interrupting.',
                      style: TextStyle(color: Colors.black87, fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kDailyChallengeRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {},
                        child: const Text(
                          'Mark Complete',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Practice Chat & Learn
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Flexible(
                    flex: 1,
                    child: _QuickAction(
                      icon: Icons.chat_bubble_outline,
                      label: 'Practice Chat',
                      subtitle: 'Simulate Conversations',
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    flex: 1,
                    child: _QuickAction(
                      icon: Icons.menu_book_outlined,
                      label: 'Learn',
                      subtitle: 'Articles & Books',
                      onTap: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Progress
              Text(
                'Your Progress',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: 2850 / 3000,
                      color: kProgressBar,
                      backgroundColor: kProgressBar.withOpacity(0.15),
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '2,850/3,000 XP',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '150 XP left to advance to the next level',
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Your Activity section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Activity',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'My library',
                    style: TextStyle(
                      color: kPrimaryBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Activity Cards
              Row(
                children: [
                  Flexible(
                    flex: 1,
                    child: _ActivityCard(
                      color: kScenarioBlue,
                      title: 'Dealing with Office Conflict',
                      type: 'Scenario',
                      icon: Icons.psychology_alt,
                      buttonText: 'Replay Scenario',
                      onButtonPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    flex: 1,
                    child: _ActivityCard(
                      color: kArticleOrange,
                      title: 'Developing Effective Communication Skills',
                      type: 'Article',
                      icon: Icons.person_search,
                      buttonText: 'Continue Reading',
                      progress: 0.6,
                      onButtonPressed: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// Quick Action Button (Practice Chat, Learn)
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: kPrimaryBlue, size: 30),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: kPrimaryBlue,
                fontSize: 15,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

// Activity Card
class _ActivityCard extends StatelessWidget {
  final Color color;
  final String title;
  final String type;
  final IconData icon;
  final String buttonText;
  final double? progress;
  final VoidCallback onButtonPressed;

  const _ActivityCard({
    required this.color,
    required this.title,
    required this.type,
    required this.icon,
    required this.buttonText,
    required this.onButtonPressed,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Icon(icon, color: Colors.white, size: 60),
          ),
          Row(
            children: [
              if (progress != null)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${(progress! * 100).round()}%",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: color,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: onButtonPressed,
                            child: Text(
                              buttonText,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (progress == null)
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: color,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: onButtonPressed,
                    child: Text(
                      buttonText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
