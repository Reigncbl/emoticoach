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
        
        if (intent.action == "SHOW_OVERLAY") {
            Log.d("MainActivity", "Triggering overlay from intent")
            try {
                // Try to invoke the method channel with callback
                overlayMethodChannel.invokeMethod("showOverlay", mapOf(
                    "trigger" to intent.getStringExtra("trigger"),
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
                Log.d("MainActivity", "Overlay method invoked successfully")
            } catch (e: Exception) {
                Log.e("MainActivity", "Error invoking overlay method", e)
            }
        }
    }
    
    override fun onResume() {
        super.onResume()
        Log.d("MainActivity", "MainActivity resumed")
        
        // Check if we have a pending overlay intent
        if (intent?.action == "SHOW_OVERLAY") {
            Log.d("MainActivity", "Processing pending overlay intent on resume")
            try {
                overlayMethodChannel.invokeMethod("showOverlay", mapOf(
                    "trigger" to intent.getStringExtra("trigger"),
                    "timestamp" to System.currentTimeMillis()
                ))
                Log.d("MainActivity", "Pending overlay method invoked successfully")
            } catch (e: Exception) {
                Log.e("MainActivity", "Error invoking pending overlay method", e)
            }
        }
    }
}
