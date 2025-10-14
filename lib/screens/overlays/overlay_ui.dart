import 'dart:async';
import 'dart:isolate';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'overlay_edit.dart';
import 'contacts_list.dart';
import 'analysis_view.dart';
import '../../services/session_service.dart';

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
  String _selectedContactPhone = ''; // Track selected contact phone
  int _selectedContactId = 0; // Track selected contact ID
  String _userPhoneNumber = ''; // User's phone number from session
  String _draftResponse = 'User text not loaded';
  SendPort? homePort;

  @override
  void initState() {
    super.initState();
    _loadUserPhoneNumber();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setOverlayFocus(false);
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

  double? _deviceLogicalWidth() {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    ui.FlutterView? view;
    if (dispatcher.views.isNotEmpty) {
      view = dispatcher.views.first;
    } else {
      view = dispatcher.implicitView;
    }
    if (view == null) {
      return null;
    }
    return view.physicalSize.width / view.devicePixelRatio;
  }

  Future<void> _setOverlayFocus(bool focusable) async {
    try {
      await FlutterOverlayWindow.updateFlag(
        focusable ? OverlayFlag.focusPointer : OverlayFlag.defaultFlag,
      );
    } catch (e) {
      debugPrint('Failed to update overlay flag: $e');
    }
  }

  int _expandedOverlayWidth() {
    final width = _deviceLogicalWidth() ?? MediaQuery.of(context).size.width;
    final desiredWidth = width * 0.95;
    final clampedWidth = desiredWidth.clamp(400.0, 500.0);
    return clampedWidth.toInt();
  }

  Future<void> _resizeOverlaySafely(
    int width,
    int height, {
    required bool enableDrag,
  }) async {
    OverlayPosition? originalPosition;
    final screenWidth = _deviceLogicalWidth();

    if (screenWidth != null) {
      try {
        originalPosition = await FlutterOverlayWindow.getOverlayPosition();
      } catch (e) {
        debugPrint('Failed to read overlay position before resize: $e');
      }
    }

    await FlutterOverlayWindow.resizeOverlay(width, height, enableDrag);

    if (screenWidth == null) {
      return;
    }

    try {
      OverlayPosition? currentPosition;
      try {
        currentPosition = await FlutterOverlayWindow.getOverlayPosition();
      } catch (e) {
        debugPrint('Failed to read overlay position after resize: $e');
        currentPosition = originalPosition;
      }

      final double maxAllowedX = (screenWidth - width).clamp(
        0.0,
        double.infinity,
      );
      final double fallbackY = currentPosition?.y ?? originalPosition?.y ?? 0;

      double? currentX = currentPosition?.x;

      // If we still can't determine the current X, keep the overlay on-screen by
      // anchoring it to the right edge (maxAllowedX) which guarantees visibility.
      if (currentX == null) {
        await FlutterOverlayWindow.moveOverlay(
          OverlayPosition(maxAllowedX, fallbackY),
        );
        return;
      }

      final double targetX = currentX.clamp(0.0, maxAllowedX);

      if ((targetX - currentX).abs() > 0.5) {
        await FlutterOverlayWindow.moveOverlay(
          OverlayPosition(targetX, fallbackY),
        );
      }
    } catch (e) {
      debugPrint('Failed to adjust overlay position after resize: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: _showEditScreen
          ? EditOverlayScreen(
              initialText: _draftResponse,
              selectedContact: _selectedContact,
              contactPhone: _selectedContactPhone,
              contactId: _selectedContactId,
              userPhoneNumber: _userPhoneNumber,
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
    final overlayWidth = _expandedOverlayWidth();
    await _resizeOverlaySafely(overlayWidth, 550, enableDrag: false);
    setState(() {
      _showEditScreen = false;
    });
  }

  // Add this method to handle going to edit screen
  void _goToEditScreen(String initialText) async {
    final overlayWidth = _expandedOverlayWidth();
    await _resizeOverlaySafely(overlayWidth, 550, enableDrag: false);
    await _setOverlayFocus(true);
    setState(() {
      _draftResponse = initialText.isNotEmpty
          ? initialText
          : 'User text not loaded';
      _showEditScreen = true;
    });
  }

  Widget _buildCircleView() {
    return GestureDetector(
      onTap: () async {
        final overlayWidth = _expandedOverlayWidth();
        await _resizeOverlaySafely(overlayWidth, 550, enableDrag: false);
        await _setOverlayFocus(true);
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
  void _selectContact(Map<String, dynamic> contact) async {
    setState(() {
      _selectedContact = contact['name'] ?? 'Unknown Contact';
      _selectedContactPhone = contact['phone'] ?? '';
      _selectedContactId = contact['id'] ?? 0;
      _showContactsList = false;
      _draftResponse = 'User text not loaded';
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
    await _resizeOverlaySafely(80, 80, enableDrag: true);
    await _setOverlayFocus(false);
    setState(() {
      _currentShape = BoxShape.circle;
      _showContactsList = false;
      _selectedContact = '';
      _selectedContactId = 0;
      _draftResponse = 'User text not loaded';
    });
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
