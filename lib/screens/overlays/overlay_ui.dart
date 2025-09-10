import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'overlay_edit.dart';
import 'contacts_list.dart';
import 'analysis_view.dart';

class OverlayUI extends StatefulWidget {
  const OverlayUI({super.key});

  @override
  State<OverlayUI> createState() => _OverlayUIState();
}

class _OverlayUIState extends State<OverlayUI> {
  BoxShape _currentShape = BoxShape.circle; // Start with circle
  bool _showEditScreen = false; // Add this state variable
  bool _showContactsList = false; // Add contacts list state
  String _selectedContact = ''; // Track selected contact
  SendPort? homePort;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: _showEditScreen
          ? EditOverlayScreen(
              initialText: 'Okay po. Ingat po palagi.',
              onBack: _goBackToMainScreen,
            )
          : (_currentShape == BoxShape.circle
                ? _buildCircleView()
                : (_showContactsList
                      ? _buildContactsListView()
                      : _buildAnalysisView())),
    );
  }

  // Add this method to handle going back to main screen
  void _goBackToMainScreen() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final overlayWidth = (screenWidth * 0.95).clamp(400.0, 500.0);
    await FlutterOverlayWindow.resizeOverlay(overlayWidth.toInt(), 550, false);
    setState(() {
      _showEditScreen = false;
    });
  }

  // Add this method to handle going to edit screen
  void _goToEditScreen() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final overlayWidth = (screenWidth * 0.95).clamp(400.0, 500.0);
    await FlutterOverlayWindow.resizeOverlay(overlayWidth.toInt(), 550, false);
    setState(() {
      _showEditScreen = true;
    });
  }

  Widget _buildCircleView() {
    return GestureDetector(
      onTap: () async {
        final screenWidth = MediaQuery.of(context).size.width;
        final overlayWidth = (screenWidth * 0.95).clamp(400.0, 500.0);
        await FlutterOverlayWindow.resizeOverlay(
          overlayWidth.toInt(),
          550,
          false,
        );
        setState(() {
          _currentShape = BoxShape.rectangle;
          _showContactsList = true; // Show contacts list first
        });
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
        child: Center(
          child: SizedBox(
            height: 80,
            width: 80,
            child: Icon(
              Icons.chat_bubble_outline,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }

  // Add method to select contact and show analysis
  void _selectContact(Map<String, dynamic> contact) {
    setState(() {
      _selectedContact = contact['name'] ?? 'Unknown Contact';
      _showContactsList = false;
    });
  }

  // Add method to go back to contacts list
  void _goBackToContacts() {
    setState(() {
      _showContactsList = true;
    });
  }

  // Helper method to close overlay
  void _closeOverlay() async {
    await FlutterOverlayWindow.resizeOverlay(80, 80, true);
    setState(() {
      _currentShape = BoxShape.circle;
      _showContactsList = false;
      _selectedContact = '';
    });
  }

  Widget _buildContactsListView() {
    return ContactsListView(
      onContactSelected: _selectContact,
      onClose: _closeOverlay,
      userMobileNumber:
          '+639762325664', // TODO: Get this from user session/state
    );
  }

  Widget _buildAnalysisView() {
    return AnalysisView(
      selectedContact: _selectedContact,
      onClose: _closeOverlay,
      onEdit: _goToEditScreen,
      onBackToContacts: _goBackToContacts,
    );
  }
}
