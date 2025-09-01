package com.example.emoticoach

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.app.usage.UsageStatsManager
import android.app.usage.UsageEvents
import android.os.Handler
import android.os.Looper

class ForegroundAppMonitorService : Service() {

    private val CHANNEL_ID = "emoticoach_overlay_channel"
    private val NOTIFICATION_ID = 1001
    
    // Multiple Telegram package names to monitor
    private val TELEGRAM_PACKAGES = listOf(
        "org.telegram.messenger",
        "org.telegram.plus",
        "org.thunderdog.challegram",
        "nekox.messenger",
        "org.telegram.messenger.web"
    )

    private var handler: Handler? = null
    private var monitoringRunnable: Runnable? = null
    private var lastDetectedApp: String? = null
    private var lastDetectionTime: Long = 0

    override fun onCreate() {
        super.onCreate()
        Log.d("EmoticoachService", "Service created")
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        startMonitoring()
    }

    private fun startMonitoring() {
        Log.d("EmoticoachService", "Starting Telegram monitoring")
        handler = Handler(Looper.getMainLooper())
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        monitoringRunnable = object : Runnable {
            override fun run() {
                try {
                    checkForTelegramLaunch(usageStatsManager)
                } catch (e: Exception) {
                    Log.e("EmoticoachService", "Error during monitoring", e)
                }
                handler?.postDelayed(this, 2000) // Check every 2 seconds
            }
        }
        
        handler?.post(monitoringRunnable!!)
    }

    private fun checkForTelegramLaunch(usageStatsManager: UsageStatsManager) {
        val endTime = System.currentTimeMillis()
        val startTime = endTime - 5000 // Check last 5 seconds

        try {
            val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
            val event = UsageEvents.Event()

            while (usageEvents.hasNextEvent()) {
                usageEvents.getNextEvent(event)
                
                if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED &&
                    TELEGRAM_PACKAGES.contains(event.packageName)
                ) {
                    // Only trigger if this is a different app than last detected
                    // or if enough time has passed since last detection
                    val shouldTrigger = lastDetectedApp != event.packageName || 
                                      (endTime - lastDetectionTime > 30000) // 30 seconds cooldown
                    
                    if (shouldTrigger) {
                        Log.d("EmoticoachService", "✅ Telegram detected: ${event.packageName} at ${event.timeStamp}")
                        lastDetectedApp = event.packageName
                        lastDetectionTime = endTime
                        showOverlay()
                        break
                    } else {
                        Log.d("EmoticoachService", "⏭️ Telegram already detected recently, skipping")
                    }
                }
            }
        } catch (e: SecurityException) {
            Log.e("EmoticoachService", "❌ Usage stats permission not granted", e)
        } catch (e: Exception) {
            Log.e("EmoticoachService", "❌ Error checking usage events", e)
        }
    }

    private fun showOverlay() {
        Log.d("EmoticoachService", "Triggering overlay display via broadcast")
        try {
            // Send broadcast to trigger overlay without affecting current app
            val intent = Intent("com.example.emoticoach.SHOW_OVERLAY_BROADCAST")
            intent.setPackage(packageName) // Ensure it only goes to our app
            intent.putExtra("trigger", "telegram_detected")
            intent.putExtra("timestamp", System.currentTimeMillis())
            sendBroadcast(intent)
            Log.d("EmoticoachService", "✅ Overlay broadcast sent successfully")
            
        } catch (e: Exception) {
            Log.e("EmoticoachService", "❌ Error sending overlay broadcast", e)
        }
    }

    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent, 
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )

        val notificationBuilder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return notificationBuilder
            .setContentTitle("EmotiCoach Active")
            .setContentText("Monitoring for Telegram launches...")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "EmotiCoach Overlay Monitor",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors for Telegram app launches"
                setShowBadge(false)
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
            Log.d("EmoticoachService", "Notification channel created")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("EmoticoachService", "Service start command received")
        return START_STICKY // Restart if killed
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.d("EmoticoachService", "Service being destroyed")
        handler?.removeCallbacks(monitoringRunnable!!)
        handler = null
        super.onDestroy()
    }
}