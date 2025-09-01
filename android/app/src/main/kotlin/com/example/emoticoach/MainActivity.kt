package com.example.emoticoach

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.app.AppOpsManager
import android.content.Context
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "emoticoach_service"
    private val OVERLAY_CHANNEL = "emoticoach_overlay_channel"
    private val USAGE_STATS_REQUEST_CODE = 1001
    
    private lateinit var overlayMethodChannel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up overlay method channel
        overlayMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsageStatsPermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "requestUsageStatsPermission" -> {
                    requestUsageStatsPermission()
                    result.success(null)
                }
                "startMonitoringService" -> {
                    startMonitoringService()
                    result.success(null)
                }
                "stopMonitoringService" -> {
                    stopMonitoringService()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        return try {
            val appOpsManager = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOpsManager.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOpsManager.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    packageName
                )
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) {
            Log.e("MainActivity", "Error checking usage stats permission", e)
            false
        }
    }

    private fun requestUsageStatsPermission() {
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            intent.data = Uri.parse("package:$packageName")
            startActivityForResult(intent, USAGE_STATS_REQUEST_CODE)
        } catch (e: Exception) {
            Log.e("MainActivity", "Error requesting usage stats permission", e)
            // Fallback to general usage access settings
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            startActivity(intent)
        }
    }

    private fun startMonitoringService() {
        try {
            val serviceIntent = Intent(this, ForegroundAppMonitorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
            Log.d("MainActivity", "Monitoring service started")
        } catch (e: Exception) {
            Log.e("MainActivity", "Error starting monitoring service", e)
        }
    }

    private fun stopMonitoringService() {
        try {
            val serviceIntent = Intent(this, ForegroundAppMonitorService::class.java)
            stopService(serviceIntent)
            Log.d("MainActivity", "Monitoring service stopped")
        } catch (e: Exception) {
            Log.e("MainActivity", "Error stopping monitoring service", e)
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d("MainActivity", "onNewIntent called with action: ${intent.action}")
        
        when (intent.action) {
            "SHOW_OVERLAY" -> {
                Log.d("MainActivity", "Triggering overlay from intent (bringing app to foreground)")
                showOverlayWithDelay(intent)
            }
            "SHOW_OVERLAY_ONLY" -> {
                Log.d("MainActivity", "Triggering overlay only (staying in background)")
                showOverlayWithDelay(intent)
                // Immediately move the activity to background
                moveTaskToBack(true)
            }
            "SILENT_OVERLAY_TRIGGER" -> {
                Log.d("MainActivity", "Silent overlay trigger - showing overlay without UI interaction")
                showOverlayWithDelay(intent)
                // Immediately finish the activity to avoid bringing app to foreground
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    finish()
                }, 100)
            }
            "BACKGROUND_OVERLAY_TRIGGER" -> {
                Log.d("MainActivity", "Background overlay trigger - showing overlay and minimizing")
                showOverlayWithDelay(intent)
                // Immediately minimize the app
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    moveTaskToBack(true)
                    Log.d("MainActivity", "App moved to background after overlay trigger")
                }, 50)
            }
        }
    }
    
    private fun showOverlayWithDelay(intent: Intent) {
        // Delay the overlay trigger to ensure the app is ready
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            try {
                overlayMethodChannel.invokeMethod("showOverlay", mapOf(
                    "trigger" to (intent.getStringExtra("trigger") ?: "manual"),
                    "timestamp" to System.currentTimeMillis()
                ), object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        Log.d("MainActivity", "✅ Overlay method call succeeded: $result")
                    }
                    
                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        Log.e("MainActivity", "❌ Overlay method call failed: $errorCode - $errorMessage")
                    }
                    
                    override fun notImplemented() {
                        Log.e("MainActivity", "❌ Overlay method not implemented")
                    }
                })
            } catch (e: Exception) {
                Log.e("MainActivity", "Error invoking overlay method", e)
            }
        }, 200) // Reduced delay to 200ms for faster response
    }
    
    override fun onResume() {
        super.onResume()
        Log.d("MainActivity", "MainActivity resumed")
        
        // Check if we have a pending overlay intent
        when (intent?.action) {
            "SHOW_OVERLAY" -> {
                Log.d("MainActivity", "Processing pending SHOW_OVERLAY intent on resume")
                showOverlayWithDelay(intent)
            }
            "SHOW_OVERLAY_ONLY" -> {
                Log.d("MainActivity", "Processing pending SHOW_OVERLAY_ONLY intent on resume")
                showOverlayWithDelay(intent)
                // Move to background after showing overlay
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    moveTaskToBack(true)
                }, 1000)
            }
            "SILENT_OVERLAY_TRIGGER" -> {
                Log.d("MainActivity", "Processing silent overlay trigger on resume")
                showOverlayWithDelay(intent)
                // Finish activity immediately for silent trigger
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    finish()
                }, 500)
            }
            "BACKGROUND_OVERLAY_TRIGGER" -> {
                Log.d("MainActivity", "Processing background overlay trigger on resume")
                showOverlayWithDelay(intent)
                // Move to background immediately
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    moveTaskToBack(true)
                    Log.d("MainActivity", "App moved to background after processing overlay")
                }, 100)
            }
        }
    }
}
