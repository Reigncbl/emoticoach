package com.example.emoticoach

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.app.AppOpsManager
import android.content.Context
import android.util.Log
import android.view.WindowManager
import android.graphics.PixelFormat
import android.view.Gravity
import android.view.View
import android.view.LayoutInflater
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Button
import androidx.core.content.ContextCompat
import android.graphics.drawable.GradientDrawable
import android.view.MotionEvent
import android.view.ViewConfiguration
import android.content.SharedPreferences
import android.util.DisplayMetrics
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "emoticoach_service"
    private val OVERLAY_CHANNEL = "emoticoach_overlay_channel"
    private val USAGE_STATS_REQUEST_CODE = 1001
    
    private lateinit var overlayMethodChannel: MethodChannel
    
    // Overlay window management
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var params: WindowManager.LayoutParams? = null
    private var isOverlayFocusable = false
    private var isExpanded = false // Track overlay state: false = bubble, true = expanded
    
    // Drag functionality variables
    private var isDragging = false
    private var initialX = 0
    private var initialY = 0
    private var initialTouchX = 0f
    private var initialTouchY = 0f
    private var touchSlop = 0
    private lateinit var sharedPrefs: SharedPreferences

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize drag functionality
        touchSlop = ViewConfiguration.get(this).scaledTouchSlop
        sharedPrefs = getSharedPreferences("overlay_prefs", Context.MODE_PRIVATE)
        
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
                "configureOverlayFlags" -> {
                    // Overlay flags are now configured directly in Flutter
                    result.success("Overlay flags configured in Flutter")
                }
                "showNativeOverlay" -> {
                    showNativeOverlay()
                    result.success("Native overlay shown")
                }
                "hideNativeOverlay" -> {
                    hideNativeOverlay()
                    result.success("Native overlay hidden")
                }
                "makeOverlayFocusable" -> {
                    makeOverlayFocusable()
                    result.success("Overlay made focusable")
                }
                "makeOverlayNonFocusable" -> {
                    makeOverlayNonFocusable()
                    result.success("Overlay made non-focusable")
                }
                "expandOverlay" -> {
                    expandOverlay()
                    result.success("Overlay expanded")
                }
                "collapseOverlay" -> {
                    collapseOverlay()
                    result.success("Overlay collapsed")
                }
                "toggleOverlayState" -> {
                    toggleOverlayState()
                    result.success("Overlay state toggled")
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
                        Log.d("MainActivity", "Overlay method call succeeded: $result")
                    }
                    
                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        Log.e("MainActivity", "Overlay method call failed: $errorCode - $errorMessage")
                    }
                    
                    override fun notImplemented() {
                        Log.e("MainActivity", "Overlay method not implemented")
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

    private fun configureOverlayWindowFlags() {
        try {
            val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            
            // Configure overlay window parameters for proper keyboard input
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or 
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                PixelFormat.TRANSLUCENT
            )
            
            params.gravity = Gravity.TOP or Gravity.START
            params.softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE or
                                   WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE
            
        } catch (e: Exception) {
            Log.e("MainActivity", "Error configuring overlay window flags", e)
        }
    }

    // Helper methods for drag functionality
    private fun getScreenWidth(): Int {
        val displayMetrics = DisplayMetrics()
        windowManager?.defaultDisplay?.getMetrics(displayMetrics)
        return displayMetrics.widthPixels
    }

    private fun getScreenHeight(): Int {
        val displayMetrics = DisplayMetrics()
        windowManager?.defaultDisplay?.getMetrics(displayMetrics)
        return displayMetrics.heightPixels
    }

    private fun snapToSide(x: Int): Int {
        val screenWidth = getScreenWidth()
        val overlayWidth = if (isExpanded) 400 else 200
        
        return if (x + overlayWidth / 2 < screenWidth / 2) {
            // Snap to left side
            20 // Small margin from edge
        } else {
            // Snap to right side
            screenWidth - overlayWidth - 20
        }
    }

    private fun saveOverlayPosition(x: Int, y: Int) {
        sharedPrefs.edit()
            .putInt("overlay_x", x)
            .putInt("overlay_y", y)
            .apply()
    }

    private fun getSavedOverlayPosition(): Pair<Int, Int> {
        val x = sharedPrefs.getInt("overlay_x", getScreenWidth() - 220) // Default to right side
        val y = sharedPrefs.getInt("overlay_y", getScreenHeight() / 2 - 100) // Default to middle vertically
        return Pair(x, y)
    }

    private fun addDragFunctionality(view: View) {
        view.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    isDragging = false
                    initialX = params?.x ?: 0
                    initialY = params?.y ?: 0
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = event.rawX - initialTouchX
                    val deltaY = event.rawY - initialTouchY
                    
                    // Check if user has moved finger enough to be considered dragging
                    if (!isDragging && (Math.abs(deltaX) > touchSlop || Math.abs(deltaY) > touchSlop)) {
                        isDragging = true
                    }
                    
                    if (isDragging) {
                        val newX = initialX + deltaX.toInt()
                        val newY = initialY + deltaY.toInt()
                        
                        // Constrain to screen boundaries
                        val overlayWidth = if (isExpanded) 400 else 200
                        val overlayHeight = if (isExpanded) 300 else 200
                        val screenWidth = getScreenWidth()
                        val screenHeight = getScreenHeight()
                        
                        params?.x = Math.max(0, Math.min(newX, screenWidth - overlayWidth))
                        params?.y = Math.max(0, Math.min(newY, screenHeight - overlayHeight))
                        
                        windowManager?.updateViewLayout(overlayView, params)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (isDragging) {
                        // Snap to side
                        val snappedX = snapToSide(params?.x ?: 0)
                        params?.x = snappedX
                        windowManager?.updateViewLayout(overlayView, params)
                        
                        // Save position
                        saveOverlayPosition(params?.x ?: 0, params?.y ?: 0)
                        
                        Log.d("MainActivity", "Overlay dragged and snapped to side at (${params?.x}, ${params?.y})")
                        isDragging = false
                        true
                    } else {
                        // If not dragging, handle as click
                        false
                    }
                }
                else -> false
            }
        }
    }

    // Native overlay management with two-state system (bubble and expanded)
    private fun showNativeOverlay() {
        try {
            if (overlayView != null) {
                Log.d("MainActivity", "Overlay already shown")
                return
            }

            windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

            // Start in non-focusable mode (default)
            params = WindowManager.LayoutParams(
                200, // Fixed width for better visibility
                200, // Fixed height for better visibility
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
            )

            // Use saved position or default to right side
            val savedPosition = getSavedOverlayPosition()
            params?.gravity = Gravity.TOP or Gravity.LEFT
            params?.x = savedPosition.first
            params?.y = savedPosition.second

            // Create the overlay container
            overlayView = createBubbleView()

            windowManager?.addView(overlayView, params)
            isOverlayFocusable = false
            isExpanded = false
            Log.d("MainActivity", "Native overlay shown in bubble mode at center (${params?.x}, ${params?.y}) with size (${params?.width}, ${params?.height})")

        } catch (e: Exception) {
            Log.e("MainActivity", "Error showing native overlay", e)
        }
    }

    private fun createBubbleView(): View {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(20, 20, 20, 20)

            // Create rounded background
            val drawable = GradientDrawable().apply {
                cornerRadius = 50f
                setColor(0xFF2196F3.toInt()) // Blue background
                setStroke(3, 0xFFFFFFFF.toInt()) // White border
            }
            background = drawable

            // Add emoji/icon
            addView(TextView(this@MainActivity).apply {
                text = "💬"
                textSize = 24f
                gravity = Gravity.CENTER
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    gravity = Gravity.CENTER
                }
            })

            // Add drag functionality first
            addDragFunctionality(this)

            // Click listener to toggle states (only if not dragging)
            setOnClickListener {
                if (!isDragging) {
                    Log.d("MainActivity", "Bubble tapped - toggling state")
                    toggleOverlayState()
                }
            }

            // Long click to make focusable
            setOnLongClickListener {
                if (!isDragging) {
                    Log.d("MainActivity", "Bubble long pressed - switching focus mode")
                    makeOverlayFocusable()
                    true
                } else {
                    false
                }
            }
        }
    }

    private fun createExpandedView(): View {
        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(30, 30, 30, 30)

            // Create rounded background
            val drawable = GradientDrawable().apply {
                cornerRadius = 20f
                setColor(0xFF2196F3.toInt()) // Blue background
                setStroke(3, 0xFFFFFFFF.toInt()) // White border
            }
            background = drawable

            // Add drag functionality
            addDragFunctionality(this)

            // Title
            addView(TextView(this@MainActivity).apply {
                text = "EmotiCoach"
                textSize = 18f
                setTextColor(0xFFFFFFFF.toInt())
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, 20)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
            })

            // Status text
            addView(TextView(this@MainActivity).apply {
                text = if (isOverlayFocusable) "Focusable Mode" else "Non-Focusable Mode"
                textSize = 14f
                setTextColor(0xFFE1F5FE.toInt())
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, 20)
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
            })

            // Buttons container
            val buttonsLayout = LinearLayout(this@MainActivity).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
            }

            // Collapse button
            buttonsLayout.addView(Button(this@MainActivity).apply {
                text = "Collapse"
                textSize = 12f
                setPadding(20, 10, 20, 10)
                setOnClickListener {
                    if (!isDragging) {
                        collapseOverlay()
                    }
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    marginEnd = 20
                }
            })

            // Focus toggle button
            buttonsLayout.addView(Button(this@MainActivity).apply {
                text = if (isOverlayFocusable) "Non-Focusable" else "Focusable"
                textSize = 12f
                setPadding(20, 10, 20, 10)
                setOnClickListener {
                    if (!isDragging) {
                        if (isOverlayFocusable) {
                            makeOverlayNonFocusable()
                        } else {
                            makeOverlayFocusable()
                        }
                        // Refresh the expanded view to update button text
                        if (isExpanded) {
                            expandOverlay()
                        }
                    }
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
            })

            addView(buttonsLayout)
        }
    }

    private fun hideNativeOverlay() {
        try {
            if (overlayView != null && windowManager != null) {
                windowManager?.removeView(overlayView)
                overlayView = null
                windowManager = null
                isOverlayFocusable = false
                isExpanded = false
                Log.d("MainActivity", "Native overlay hidden")
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error hiding native overlay", e)
        }
    }

    private fun expandOverlay() {
        try {
            if (overlayView == null || windowManager == null) {
                Log.w("MainActivity", "Cannot expand - overlay not shown")
                return
            }

            // Remove current view
            windowManager?.removeView(overlayView)

            // Update layout params for expanded view
            params?.width = 400 // Larger width for expanded view
            params?.height = 300 // Larger height for expanded view

            // Create expanded view
            overlayView = createExpandedView()
            
            // Add the new expanded view
            windowManager?.addView(overlayView, params)
            isExpanded = true
            
            Log.d("MainActivity", "Overlay expanded successfully with size (${params?.width}, ${params?.height})")
        } catch (e: Exception) {
            Log.e("MainActivity", "Error expanding overlay", e)
        }
    }

    private fun collapseOverlay() {
        try {
            if (overlayView == null || windowManager == null) {
                Log.w("MainActivity", "Cannot collapse - overlay not shown")
                return
            }

            // Remove current view
            windowManager?.removeView(overlayView)

            // Update layout params for bubble view
            params?.width = 200 // Fixed width for bubble view
            params?.height = 200 // Fixed height for bubble view

            // Create bubble view
            overlayView = createBubbleView()
            
            // Add the new bubble view
            windowManager?.addView(overlayView, params)
            isExpanded = false
            
            Log.d("MainActivity", "Overlay collapsed successfully with size (${params?.width}, ${params?.height})")
        } catch (e: Exception) {
            Log.e("MainActivity", "Error collapsing overlay", e)
        }
    }

    private fun toggleOverlayState() {
        if (isExpanded) {
            collapseOverlay()
        } else {
            expandOverlay()
        }
    }

    private fun makeOverlayFocusable() {
        try {
            if (params != null && windowManager != null && overlayView != null && !isOverlayFocusable) {
                // Remove FLAG_NOT_FOCUSABLE to allow keyboard input
                params?.flags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                               WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                
                windowManager?.updateViewLayout(overlayView, params)
                isOverlayFocusable = true
                Log.d("MainActivity", "Overlay switched to focusable mode")

                // Refresh expanded view if currently expanded to update button text
                if (isExpanded) {
                    expandOverlay()
                }

                // Set up focus change listener to switch back to non-focusable when focus is lost
                overlayView?.setOnFocusChangeListener { _, hasFocus ->
                    if (!hasFocus) {
                        Log.d("MainActivity", "Overlay lost focus - switching back to non-focusable mode")
                        makeOverlayNonFocusable()
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error making overlay focusable", e)
        }
    }

    private fun makeOverlayNonFocusable() {
        try {
            if (params != null && windowManager != null && overlayView != null && isOverlayFocusable) {
                // Add FLAG_NOT_FOCUSABLE to prevent grabbing input
                params?.flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                               WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                               WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                
                windowManager?.updateViewLayout(overlayView, params)
                isOverlayFocusable = false
                Log.d("MainActivity", "Overlay switched to non-focusable mode")

                // Refresh expanded view if currently expanded to update button text
                if (isExpanded) {
                    expandOverlay()
                }
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error making overlay non-focusable", e)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clean up overlay when activity is destroyed
        hideNativeOverlay()
    }
}
