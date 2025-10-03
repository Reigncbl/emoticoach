import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _bubbleChannel = MethodChannel('emoticoach_service');

Future<void> startBubbleService() async {
  try {
    debugPrint('[BubbleHelper] startBubbleService invoked');
    await _bubbleChannel.invokeMethod('startBubbleService');
    debugPrint('[BubbleHelper] startBubbleService completed');
  } catch (e) {
    debugPrint('Failed to start bubble service: $e');
  }
}

Future<void> stopBubbleService() async {
  try {
    debugPrint('[BubbleHelper] stopBubbleService invoked');
    await _bubbleChannel.invokeMethod('stopBubbleService');
    debugPrint('[BubbleHelper] stopBubbleService completed');
  } catch (e) {
    debugPrint('Failed to stop bubble service: $e');
  }
}

Future<void> showBubble() async {
  try {
    debugPrint('[BubbleHelper] showBubble invoked');
    await _bubbleChannel.invokeMethod('showBubble');
    debugPrint('[BubbleHelper] showBubble completed');
  } catch (e) {
    debugPrint('Failed to show bubble: $e');
  }
}

Future<void> hideBubble() async {
  try {
    debugPrint('[BubbleHelper] hideBubble invoked');
    await _bubbleChannel.invokeMethod('hideBubble');
    debugPrint('[BubbleHelper] hideBubble completed');
  } catch (e) {
    debugPrint('Failed to hide bubble: $e');
  }
}

Future<bool> isBubbleActive() async {
  try {
    debugPrint('[BubbleHelper] isBubbleActive check requested');
    final result = await _bubbleChannel.invokeMethod<bool>('isBubbleVisible');
    debugPrint('[BubbleHelper] isBubbleActive result: ${result ?? false}');
    return result ?? false;
  } catch (e) {
    debugPrint('Failed to check bubble visibility: $e');
    return false;
  }
}
