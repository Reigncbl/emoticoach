import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'overlay_edit.dart';
import 'contacts_list.dart';
import 'analysis_view.dart';
import '../../services/session_service.dart';

extension StringCapitalization on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

class OverlayUI extends StatefulWidget {
  const OverlayUI({super.key});

  @override
  State<OverlayUI> createState() => _OverlayUIState();
}

class _OverlayUIState extends State<OverlayUI> {
  static const MethodChannel _channel = MethodChannel('overlay_communication');

  String _selectedContact = ''; // Track selected contact
  String _selectedContactPhone = ''; // Track selected contact phone
  int _selectedContactId = 0; // Track selected contact ID
  String _userPhoneNumber = ''; // User's phone number from session
  String _currentView = 'bubble'; // Track current view type
  Map<String, dynamic>? _viewData; // Data passed between views
  SendPort? homePort;

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
    _loadUserPhoneNumber();
  }

  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'setOverlayView':
          final String viewType = call.arguments['viewType'] ?? 'bubble';
          final Map<String, dynamic>? data = call.arguments['data'];
          _handleViewSwitch(viewType, data);
          break;
        case 'switchView':
          final String viewType = call.arguments['viewType'] ?? 'bubble';
          final Map<String, dynamic>? data = call.arguments['data'];
          _handleViewSwitch(viewType, data);
          break;
      }
    });
  }

  void _handleViewSwitch(String viewType, Map<String, dynamic>? data) {
    setState(() {
      _currentView = viewType;
      _viewData = data;

      // Update selected contact data for analysis and edit views
      if (viewType == 'analysis' && data != null) {
        _selectedContact = data['name'] ?? 'Unknown Contact';
        _selectedContactPhone = data['phone'] ?? '';
        _selectedContactId = data['id'] ?? 0;
      }
    });
  }

  void _switchToView(String viewType, [Map<String, dynamic>? data]) {
    // Communicate back to native Android to handle sizing and state
    _channel.invokeMethod('switch${viewType.capitalize()}', data);
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

  @override
  Widget build(BuildContext context) {
    return Material(color: Colors.transparent, child: _buildCurrentView());
  }

  Widget _buildCurrentView() {
    // Use _currentView to determine which view to show
    switch (_currentView) {
      case 'contacts':
        return _buildContactsListView();
      case 'analysis':
        return _buildAnalysisView();
      case 'edit':
        return EditOverlayScreen(
          initialText: 'User text not loaded',
          selectedContact: _selectedContact,
          contactPhone: _selectedContactPhone,
          userPhoneNumber: _userPhoneNumber,
          onBack: _goBackToMainScreen,
        );
      case 'bubble':
      default:
        return _buildCircleView();
    }
  }

  // Add this method to handle going back to main screen
  void _goBackToMainScreen() {
    _switchToView('analysis');
  }

  // Add this method to handle going to edit screen
  void _goToEditScreen() {
    _switchToView('edit');
  }

  Widget _buildCircleView() {
    return GestureDetector(
      onTap: () {
        print('Bubble tapped - switching to contacts');
        _switchToView('contacts');
      },
      onLongPress: () {
        print('Bubble long pressed');
        // TODO: Add long press functionality like making overlay focusable
      },
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          shape: BoxShape.circle,
        ),
        child: const Center(child: Text('💬', style: TextStyle(fontSize: 32))),
      ),
    );
  }

  // Add method to select contact and show analysis
  void _selectContact(Map<String, dynamic> contact) {
    _switchToView('analysis', contact);
  }

  // Add method to go back to contacts list
  void _goBackToContacts() {
    _switchToView('contacts');
  }

  // Helper method to close overlay
  void _closeOverlay() {
    _switchToView('bubble');
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
