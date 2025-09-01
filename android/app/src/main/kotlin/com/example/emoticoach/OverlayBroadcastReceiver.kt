package com.example.emoticoach

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class OverlayBroadcastReceiver : BroadcastReceiver() {
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("OverlayReceiver", "Broadcast received: ${intent.action}")
        
        if (intent.action == "com.example.emoticoach.SHOW_OVERLAY_BROADCAST") {
            Log.d("OverlayReceiver", "Triggering overlay without bringing app to foreground")
            triggerOverlayBackground(context)
        }
    }
    
    private fun triggerOverlayBackground(context: Context) {
        try {
            // Use a special intent that starts the activity but immediately moves it to background
            val intent = Intent(context, MainActivity::class.java).apply {
                action = "BACKGROUND_OVERLAY_TRIGGER"
                putExtra("trigger", "telegram_detected")
                putExtra("timestamp", System.currentTimeMillis())
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                       Intent.FLAG_ACTIVITY_SINGLE_TOP or
                       Intent.FLAG_ACTIVITY_NO_ANIMATION
            }
            
            context.startActivity(intent)
            Log.d("OverlayReceiver", "✅ Background overlay trigger sent")
            
        } catch (e: Exception) {
            Log.e("OverlayReceiver", "❌ Error triggering background overlay", e)
        }
    }
}