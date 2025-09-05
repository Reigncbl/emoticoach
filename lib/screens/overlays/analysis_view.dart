import 'package:flutter/material.dart';

class AnalysisView extends StatelessWidget {
  final String selectedContact;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onBackToContacts;

  const AnalysisView({
    super.key,
    required this.selectedContact,
    required this.onClose,
    required this.onEdit,
    required this.onBackToContacts,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final containerWidth = screenWidth * 0.95; // 90% of screen width
    final maxWidth = 500.0; // Maximum width limit
    final finalWidth = containerWidth > maxWidth ? maxWidth : containerWidth;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        width: finalWidth,
        height: 550,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(children: [_buildHeader(), _buildContent()]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: onBackToContacts,
            child: Container(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.arrow_back, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white,
            child: Icon(Icons.face, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Message from $selectedContact:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMessageBubble(),
            const SizedBox(height: 14),
            _buildToneSection(),
            const SizedBox(height: 10),
            _buildInterpretationSection(),
            const SizedBox(height: 10),
            _buildSuggestedResponseSection(),
            const SizedBox(height: 10),
            _buildChecklist(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Text(
        _getMessageForContact(selectedContact),
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildToneSection() {
    return _buildSection(
      icon: '🔍',
      title: 'Detected Tone',
      content: _getToneForContact(selectedContact),
    );
  }

  Widget _buildInterpretationSection() {
    return _buildSection(
      icon: '📝',
      title: 'Interpretation',
      content: _getInterpretationForContact(selectedContact),
    );
  }

  Widget _buildSuggestedResponseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '💡 Suggested Response',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.green.shade300),
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getSuggestedResponseForContact(selectedContact),
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.check_circle_outline,
                    label: 'Use',
                    color: Colors.green,
                    onTap: () {
                      // Handle use action
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.edit,
                    label: 'Edit',
                    color: Colors.blue,
                    onTap: onEdit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChecklist() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Text(
        _getChecklistForContact(selectedContact),
        style: const TextStyle(color: Colors.blue, fontSize: 11, height: 1.3),
      ),
    );
  }

  Widget _buildSection({
    required String icon,
    required String title,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$icon $title',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          content,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 12,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods to get contact-specific data
  String _getMessageForContact(String contact) {
    switch (contact) {
      case 'Carlo Lorieta':
        return '"Let\'s just skip the technical details and move on, hahahahaha!"';
      case 'Maria Santos':
        return '"Thanks for the help! I really appreciate it."';
      case 'John Dela Cruz':
        return '"See you tomorrow at the meeting."';
      case 'Sarah Kim':
        return '"Great job on the presentation! Very well done."';
      default:
        return '"Sample message from $contact"';
    }
  }

  String _getToneForContact(String contact) {
    switch (contact) {
      case 'Carlo Lorieta':
        return 'Casual & Playful';
      case 'Maria Santos':
        return 'Grateful & Friendly';
      case 'John Dela Cruz':
        return 'Professional & Brief';
      case 'Sarah Kim':
        return 'Encouraging & Positive';
      default:
        return 'Neutral';
    }
  }

  String _getInterpretationForContact(String contact) {
    switch (contact) {
      case 'Carlo Lorieta':
        return 'Carlo seems to be keeping the mood light and understanding. He\'s probably saying it\'s okay to drop the topic.';
      case 'Maria Santos':
        return 'Maria is expressing genuine gratitude and wants to maintain a positive relationship.';
      case 'John Dela Cruz':
        return 'John is being direct and professional, focusing on the next meeting.';
      case 'Sarah Kim':
        return 'Sarah is giving positive feedback and encouragement for your work.';
      default:
        return 'The message appears to be neutral in tone.';
    }
  }

  String _getSuggestedResponseForContact(String contact) {
    switch (contact) {
      case 'Carlo Lorieta':
        return 'Thank you po for understanding! Wishing you and the team all the best din 🫶';
      case 'Maria Santos':
        return 'You\'re very welcome! Happy to help anytime 😊';
      case 'John Dela Cruz':
        return 'Looking forward to it! See you there.';
      case 'Sarah Kim':
        return 'Thank you so much! I really appreciate your kind words 🙏';
      default:
        return 'Thank you for your message!';
    }
  }

  String _getChecklistForContact(String contact) {
    switch (contact) {
      case 'Carlo Lorieta':
        return '✓ Keeps things friendly\n✓ Acknowledges his tone\n✓ Closes the convo on a good note';
      case 'Maria Santos':
        return '✓ Acknowledges gratitude\n✓ Maintains warm tone\n✓ Offers future help';
      case 'John Dela Cruz':
        return '✓ Professional response\n✓ Confirms attendance\n✓ Brief and appropriate';
      case 'Sarah Kim':
        return '✓ Shows appreciation\n✓ Humble response\n✓ Positive engagement';
      default:
        return '✓ Appropriate response\n✓ Maintains tone\n✓ Clear communication';
    }
  }
}
