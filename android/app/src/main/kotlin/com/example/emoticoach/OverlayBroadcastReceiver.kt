package com.example.emoticoach

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class OverlayBroadcastReceiver : BroadcastReceiver() {
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("OverlayReceiver", "Broadcast received: ${intent.action}")
        
        if (intent.action == "com.example.emoticoach.SHOW_OVERLAY_BROADCAST") {
            Log.d("OverlayReceiver", "Showing overlay from broadcast")
            showOverlay(context)
        }
    }
    
    private fun showOverlay(context: Context) {
        try {
            // Create a Flutter engine specifically for overlay
            val flutterEngine = FlutterEngine(context)
            
            // Execute the overlay entry point
            flutterEngine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
            
            // Wait a moment for engine to initialize
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                try {
                    val overlayChannel = MethodChannel(
                        flutterEngine.dartExecutor.binaryMessenger,
                        "flutter_overlay_window"
                    )
                    
                    overlayChannel.invokeMethod("showOverlay", mapOf(
                        "enableDrag" to false, // Disable dragging to keep bubble on side
                        "overlayTitle" to "Emoticoach",
                        "overlayContent" to "Telegram detected - Overlay activated",
                        "flag" to "defaultFlag",
                        "visibility" to "visibilityPublic",
                        "positionGravity" to "right",
                        "height" to 80,
                        "width" to 80,
                        "startPosition" to mapOf("x" to 0, "y" to 300)
                    ), object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            Log.d("OverlayReceiver", "✅ Overlay shown successfully")
                        }
                        
                        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                            Log.e("OverlayReceiver", "❌ Overlay failed: $errorCode - $errorMessage")
                        }
                        
                        override fun notImplemented() {
                            Log.e("OverlayReceiver", "❌ Overlay method not implemented")
                        }
                    })
                } catch (e: Exception) {
                    Log.e("OverlayReceiver", "Error showing overlay", e)
                }
            }, 1000) // Wait 1 second for Flutter engine to be ready
            
        } catch (e: Exception) {
            Log.e("OverlayReceiver", "Error creating Flutter engine", e)
        }
    }
}