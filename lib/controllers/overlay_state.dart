import 'package:flutter/foundation.dart';

enum OverlayViewState { full, bubble }

class OverlayStateController {
  static final ValueNotifier<OverlayViewState> overlayStateNotifier =
      ValueNotifier<OverlayViewState>(OverlayViewState.full);

  static OverlayViewState get currentView => overlayStateNotifier.value;

  static void switchToFull() {
    overlayStateNotifier.value = OverlayViewState.full;
  }

  static void switchToBubble() {
    overlayStateNotifier.value = OverlayViewState.bubble;
  }
}
