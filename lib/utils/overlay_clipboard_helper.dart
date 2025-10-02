import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/services.dart';

const String overlayClipboardPortName = 'emoticoach_overlay_clipboard';
const MethodChannel _clipboardChannel = MethodChannel(
  'com.example.emoticoach/clipboard',
);

/// Attempts to copy [text] to the clipboard when running inside the overlay isolate.
///
/// Order of attempts:
/// 1. Send the copy request to the main isolate (if available) via [IsolateNameServer].
/// 2. Call the Android native channel (registered in the main activity).
/// 3. Fallback to Flutter's [Clipboard] API.
Future<bool> copyTextFromOverlay(String text) async {
  if (text.isEmpty) return false;

  // Try bridging to the main isolate so the copy executes on the primary engine.
  final sendPort = IsolateNameServer.lookupPortByName(overlayClipboardPortName);
  if (sendPort != null) {
    final responsePort = ReceivePort();
    try {
      sendPort.send({
        'action': 'copy',
        'text': text,
        'replyPort': responsePort.sendPort,
      });

      final response = await responsePort.first.timeout(
        const Duration(milliseconds: 600),
      );
      if (response is Map && response['success'] == true) {
        return true;
      }
    } catch (_) {
      // Ignore and continue to native fallback
    } finally {
      responsePort.close();
    }
  }

  // Native clipboard via method channel (works when the activity engine handles the channel).
  try {
    final ok = await _clipboardChannel.invokeMethod<bool>('copyText', {
      'text': text,
    });
    if (ok == true) {
      return true;
    }
  } catch (_) {
    // Ignore and fallback to Flutter clipboard
  }

  // Fallback to Flutter's Clipboard API.
  try {
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  } catch (_) {
    return false;
  }
}
