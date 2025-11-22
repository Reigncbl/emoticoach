import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
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
  Timer? _loadingTimeoutTimer;
  bool _isInCloseZone = false;
  bool _loadingTimedOut = false;
  static const double _closeThresholdPercent = 0.80; // 80% down the screen
  static const int _closeDelayMs = 1500; // 500ms delay before closing
  static const Duration _loadingTimeout = Duration(seconds: 8);

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
    _loadingTimeoutTimer?.cancel();
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
      if (_userPhoneNumber.isNotEmpty) {
        _resetLoadingTimeout();
      }
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

  void _startLoadingTimeoutIfNeeded() {
    if (_loadingTimeoutTimer != null || _loadingTimedOut) {
      return;
    }
    _loadingTimeoutTimer = Timer(_loadingTimeout, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingTimedOut = true;
      });
    });
  }

  void _resetLoadingTimeout() {
    _loadingTimeoutTimer?.cancel();
    _loadingTimeoutTimer = null;
    _loadingTimedOut = false;
  }

  void _retryLoadingSessionData() {
    _resetLoadingTimeout();
    _loadUserPhoneNumber();
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
    final screenWidth = _deviceLogicalWidth() ?? MediaQuery.of(context).size.width;
    final double maxWidth = math.min(500.0, screenWidth - 20.0);
    final double minWidth = 400.0;
    final desiredWidth = screenWidth * 0.95;
    final clampedWidth = desiredWidth.clamp(minWidth, math.max(minWidth, maxWidth));
    return clampedWidth.toInt();
  }

  Future<void> _resizeOverlaySafely(
    int width,
    int height, {
    required bool enableDrag,
    double? previousWidth,
    bool preserveRightEdge = false,
    double? preferredX,
    double? preferredY,
  }) async {
    OverlayPosition? originalPosition;
    final screenWidth = _deviceLogicalWidth();
    final screenHeight = _getScreenHeight();

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

      final double maxAllowedX = math.max(0.0, screenWidth - width);
      final double maxAllowedY = screenHeight != null
          ? math.max(0.0, screenHeight - height.toDouble())
          : double.infinity;
      final double fallbackY = currentPosition?.y ?? originalPosition?.y ?? 0;

      double? calculatedX;

      if (preferredX != null) {
        calculatedX = preferredX;
      } else if (preserveRightEdge &&
          previousWidth != null &&
          previousWidth > 0) {
        final rightEdge = (originalPosition?.x ?? 0) + previousWidth;
        calculatedX = rightEdge - width;
      } else {
        calculatedX = currentPosition?.x ?? originalPosition?.x;
      }

      calculatedX ??= maxAllowedX;
      final double targetX = calculatedX.clamp(0.0, maxAllowedX);
      final double currentX = currentPosition?.x ?? calculatedX;
        final double targetY = ((preferredY ?? fallbackY)
            .clamp(0.0, maxAllowedY.isFinite ? maxAllowedY : double.infinity))
          .toDouble();
      final double currentY = currentPosition?.y ?? fallbackY;

      if ((targetX - currentX).abs() > 0.5 || (targetY - currentY).abs() > 0.5) {
        await FlutterOverlayWindow.moveOverlay(
          OverlayPosition(targetX, targetY),
        );
      }
    } catch (e) {
      debugPrint('Failed to adjust overlay position after resize: $e');
    }
  }

  Future<void> _centerExpandedOverlay({int height = 550}) async {
    final width = _expandedOverlayWidth();
    final screenWidth =
        _deviceLogicalWidth() ?? MediaQuery.of(context).size.width;
    final centeredX = math.max(0.0, (screenWidth - width) / 2);
    await _resizeOverlaySafely(
      width,
      height,
      enableDrag: false,
      preferredX: centeredX,
    );
  }

  Future<void> _openExpandedOverlayFromCircle({int height = 550}) async {
    final width = _expandedOverlayWidth();
    final screenWidth =
        _deviceLogicalWidth() ?? MediaQuery.of(context).size.width;

    if (screenWidth <= 0) {
      await _centerExpandedOverlay(height: height);
      return;
    }

    double targetX = math.max(0.0, (screenWidth - width) / 2);
    double? targetY;

    try {
      final position = await FlutterOverlayWindow.getOverlayPosition();
      final bubbleDiameter = 80.0;
      final bubbleCenterX = position.x + (bubbleDiameter / 2);
      final isRightSide = bubbleCenterX >= (screenWidth / 2);

        final screenHeight = _getScreenHeight();
        const desiredOffset = 200.0;
        targetY = screenHeight != null
          ? math.min(desiredOffset, math.max(0.0, screenHeight - height.toDouble()))
          : desiredOffset;
      targetX = isRightSide
          ? math.max(0.0, screenWidth - width)
          : 0.0;
    } catch (e) {
      debugPrint('Failed to determine bubble side: $e');
    }

    await _resizeOverlaySafely(
      width,
      height,
      enableDrag: false,
      preferredX: targetX,
      preferredY: targetY,
    );
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
    await _centerExpandedOverlay();
    setState(() {
      _showEditScreen = false;
    });
  }

  // Add this method to handle going to edit screen
  void _goToEditScreen(String initialText) async {
    await _centerExpandedOverlay();
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
        await _openExpandedOverlayFromCircle();
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
    _resetLoadingTimeout();
    final expandedWidth = _expandedOverlayWidth().toDouble();
    await _resizeOverlaySafely(
      80,
      80,
      enableDrag: true,
      previousWidth: expandedWidth,
      preserveRightEdge: false,
      preferredX: 0,
    );
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
      return _buildLoadingPlaceholder(message: 'Loading your contacts...');
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
      return _buildLoadingPlaceholder(message: 'Preparing messaging coach...');
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

  Widget _buildLoadingPlaceholder({required String message}) {
    _startLoadingTimeoutIfNeeded();
    if (_loadingTimedOut) {
      return _buildLoadingTimeoutFallback(message: message);
    }
    return _buildBaseContainer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            message,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Hang tight, this can take a moment.',
            style: TextStyle(color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingTimeoutFallback({required String message}) {
    return _buildBaseContainer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.hourglass_disabled,
            size: 48,
            color: Colors.deepPurple,
          ),
          const SizedBox(height: 16),
          const Text(
            'Still loading...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "$message\nIt's taking longer than expected.",
            style: const TextStyle(color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: _retryLoadingSessionData,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.expand_more),
                label: const Text('Collapse'),
                onPressed: _closeOverlay,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBaseContainer({required Widget child}) {
    return Container(
      width: 400,
      height: 550,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }
}
