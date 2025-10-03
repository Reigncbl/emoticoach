import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'overlay_edit.dart';
import 'contacts_list.dart';
import 'analysis_view.dart';
import '../../services/session_service.dart';
import '../../utils/overlay_bubble_helper.dart';

class OverlayUI extends StatefulWidget {
  const OverlayUI({super.key});

  @override
  State<OverlayUI> createState() => _OverlayUIState();
}

class _OverlayUIState extends State<OverlayUI> {
  bool _showEditScreen = false; // Add this state variable
  bool _showContactsList = true; // Add contacts list state
  String _selectedContact = ''; // Track selected contact
  String _selectedContactPhone = ''; // Track selected contact phone
  int _selectedContactId = 0; // Track selected contact ID
  String _userPhoneNumber = ''; // User's phone number from session

  @override
  void initState() {
    super.initState();
    _loadUserPhoneNumber();
    Future.microtask(hideBubble);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureExpandedLayout();
    });
  }

  // Load user phone number from session
  Future<void> _loadUserPhoneNumber() async {
    final phoneNumber = await SimpleSessionService.getUserPhone();
    if (mounted) {
      setState(() {
        _userPhoneNumber = phoneNumber ?? '';
      });
    }
  }

  Future<void> _ensureExpandedLayout() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final overlayWidth = (screenWidth * 0.95).clamp(400.0, 520.0);
    try {
      await FlutterOverlayWindow.resizeOverlay(
        overlayWidth.toInt(),
        550,
        false,
      );
    } catch (e) {
      debugPrint('Failed to resize overlay: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: _showEditScreen
            ? EditOverlayScreen(
                initialText: 'User text not loaded',
                selectedContact: _selectedContact,
                contactPhone: _selectedContactPhone,
                userPhoneNumber: _userPhoneNumber,
                onBack: _goBackToMainScreen,
              )
            : (_showContactsList
                  ? _buildContactsListView()
                  : _buildAnalysisView()),
      ),
    );
  }

  // Add this method to handle going back to main screen
  void _goBackToMainScreen() async {
    await _ensureExpandedLayout();
    if (mounted) {
      setState(() {
        _showEditScreen = false;
      });
    }
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

  // Add method to select contact and show analysis
  void _selectContact(Map<String, dynamic> contact) async {
    setState(() {
      _selectedContact = contact['name'] ?? 'Unknown Contact';
      _selectedContactPhone = contact['phone'] ?? '';
      _selectedContactId = contact['id'] ?? 0;
      _showContactsList = false;
    });
    await _ensureExpandedLayout();
  }

  // Add method to go back to contacts list
  void _goBackToContacts() {
    setState(() {
      _showContactsList = true;
    });
    _ensureExpandedLayout();
  }

  // Helper method to close overlay
  void _closeOverlay() async {
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      debugPrint('Failed to close overlay: $e');
    } finally {
      await showBubble();
      if (mounted) {
        setState(() {
          _showEditScreen = false;
          _showContactsList = true;
          _selectedContact = '';
          _selectedContactPhone = '';
          _selectedContactId = 0;
        });
      }
    }
  }

  Widget _buildContactsListView() {
    // Don't show contacts list if user phone number is not loaded yet
    if (_userPhoneNumber.isEmpty) {
      return Container(
        width: 400,
        height: 550,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return ContactsListView(
      onContactSelected: _selectContact,
      onClose: _closeOverlay,
      userMobileNumber: _userPhoneNumber,
    );
  }

  Widget _buildAnalysisView() {
    // Don't show analysis view if user phone number is not loaded yet
    if (_userPhoneNumber.isEmpty) {
      return Container(
        width: 400,
        height: 550,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return AnalysisView(
      selectedContact: _selectedContact,
      contactPhone: _selectedContactPhone,
      contactId: _selectedContactId,
      userPhoneNumber: _userPhoneNumber,
      onClose: _closeOverlay,
      onEdit: _goToEditScreen,
      onBackToContacts: _goBackToContacts,
    );
  }
}
