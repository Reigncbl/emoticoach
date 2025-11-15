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
  
  // Drag-to-close functionality
  Timer? _monitorStartDelayTimer;
  Timer? _positionCheckTimer;
  Timer? _closeDelayTimer;
  bool _isInCloseZone = false;
  static const double _closeThresholdPercent = 0.80; // 80% down the screen
  static const int _closeDelayMs = 1500; // 500ms delay before closing

  @override
  void initState() {
    super.initState();
    _loadUserPhoneNumber();
    _startPositionMonitoring();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setOverlayFocus(false);
    });
  }

  @override
  void dispose() {
    _stopPositionMonitoring();
    _closeDelayTimer?.cancel();
    _monitorStartDelayTimer?.cancel();
    super.dispose();
  }

  // Start monitoring overlay position for drag-to-close
  void _startPositionMonitoring() {
    // Delay monitoring slightly so the overlay can appear without immediate closure
    _monitorStartDelayTimer?.cancel();
    _monitorStartDelayTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) {
        return;
      }
      _positionCheckTimer?.cancel();
      _positionCheckTimer = Timer.periodic(
        const Duration(milliseconds: 300),
        (_) => _checkPositionForAutoClose(),
      );
    });
  }

  // Stop monitoring when overlay is disposed
  void _stopPositionMonitoring() {
    _positionCheckTimer?.cancel();
    _positionCheckTimer = null;
    _monitorStartDelayTimer?.cancel();
    _monitorStartDelayTimer = null;
  }

  // Check if overlay is in the close zone
  Future<void> _checkPositionForAutoClose() async {
    // Only check when in circle mode (draggable state)
    if (_currentShape != BoxShape.circle) {
      return;
    }

    try {
      final position = await FlutterOverlayWindow.getOverlayPosition();
      final screenHeight = _getScreenHeight();

      if (screenHeight == null) {
        return;
      }

      final closeThreshold = screenHeight * _closeThresholdPercent;
      final isCurrentlyInCloseZone = position.y >= closeThreshold;

      if (isCurrentlyInCloseZone && !_isInCloseZone) {
        // Just entered close zone
        if (mounted) {
          setState(() {
            _isInCloseZone = true;
          });
        }
        debugPrint(
          'Overlay entered close zone. positionY=${position.y.toStringAsFixed(1)}, threshold=${closeThreshold.toStringAsFixed(1)}',
        );
        _startCloseDelay();
      } else if (!isCurrentlyInCloseZone && _isInCloseZone) {
        // Just left close zone - cancel close
        if (mounted) {
          setState(() {
            _isInCloseZone = false;
          });
        }
        debugPrint(
          'Overlay left close zone. positionY=${position.y.toStringAsFixed(1)}, threshold=${closeThreshold.toStringAsFixed(1)}',
        );
        _cancelCloseDelay();
      }
    } catch (e) {
      debugPrint('Error checking overlay position: $e');
    }
  }

  // Start delay timer before closing
  void _startCloseDelay() {
    _closeDelayTimer?.cancel();
    _closeDelayTimer = Timer(Duration(milliseconds: _closeDelayMs), () {
      if (_isInCloseZone && _currentShape == BoxShape.circle) {
        _autoCloseOverlay();
      }
    });
  }

  // Cancel the close delay timer
  void _cancelCloseDelay() {
    _closeDelayTimer?.cancel();
    _closeDelayTimer = null;
  }

  // Auto-close the overlay
  Future<void> _autoCloseOverlay() async {
    try {
      debugPrint('Auto-closing overlay (dragged to bottom)');
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      debugPrint('Error auto-closing overlay: $e');
    }
  }

  // Get screen height
  double? _getScreenHeight() {
    final dispatcher = WidgetsBinding.instance.platformDispatcher;

    // Prefer display metrics when available because overlay views can report only their own height
    if (dispatcher.displays.isNotEmpty) {
      final display = dispatcher.displays.first;
      final fallbackView = dispatcher.views.isNotEmpty
          ? dispatcher.views.first
          : dispatcher.implicitView;
      final fallbackPixelRatio = fallbackView?.devicePixelRatio ?? 1.0;
      final pixelRatio = display.devicePixelRatio != 0
          ? display.devicePixelRatio
          : fallbackPixelRatio;
      if (pixelRatio != 0) {
        return display.size.height / pixelRatio;
      }
      return display.size.height.toDouble();
    }

    ui.FlutterView? view;
    if (dispatcher.views.isNotEmpty) {
      view = dispatcher.views.first;
    } else {
      view = dispatcher.implicitView;
    }
    if (view == null) {
      return null;
    }
    return view.physicalSize.height / view.devicePixelRatio;
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: _isInCloseZone ? Colors.red.withOpacity(0.8) : Colors.blue,
          shape: BoxShape.circle,
          boxShadow: _isInCloseZone
              ? [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: SizedBox(
            height: 80,
            width: 80,
            child: Icon(
              _isInCloseZone ? Icons.close : Icons.chat_bubble_outline,
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
    _cancelCloseDelay();
    _isInCloseZone = false;
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
