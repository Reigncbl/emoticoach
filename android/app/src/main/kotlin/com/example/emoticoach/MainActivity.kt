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
import android.widget.FrameLayout
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "emoticoach_service"
    private val OVERLAY_CHANNEL = "emoticoach_overlay_channel"
    private val OVERLAY_COMM_CHANNEL = "overlay_communication"
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
    
    // Flutter overlay integration
    private var overlayFlutterEngine: FlutterEngine? = null
    private var overlayFlutterView: FlutterView? = null
    private var overlayCommChannel: MethodChannel? = null
    private var currentOverlayView: String = "bubble" // "bubble", "contacts", "analysis", "edit"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize drag functionality
        touchSlop = ViewConfiguration.get(this).scaledTouchSlop
        sharedPrefs = getSharedPreferences("overlay_prefs", Context.MODE_PRIVATE)
        
        // Set up overlay method channel for main app communication
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
                "switchOverlayView" -> {
                    val viewType = call.argument<String>("viewType") ?: "bubble"
                    val data = call.argument<Map<String, Any>>("data")
                    switchOverlayView(viewType, data)
                    result.success("Overlay view switched to $viewType")
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

    private fun createOverlayFlutterEngine() {
        try {
            // Create a dedicated Flutter engine for overlay
            overlayFlutterEngine = FlutterEngine(this@MainActivity)
            
            // Start executing Dart code with overlay entry point
            overlayFlutterEngine?.dartExecutor?.executeDartEntrypoint(
                DartExecutor.DartEntrypoint("package:emoticoach/main.dart", "overlayMain")
            )
            
            // Create method channel for overlay communication
            overlayCommChannel = MethodChannel(
                overlayFlutterEngine!!.dartExecutor.binaryMessenger,
                OVERLAY_COMM_CHANNEL
            )
            
            // Set up method call handler for overlay-specific methods
            overlayCommChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "switchToContacts" -> {
                        switchOverlayView("contacts")
                        result.success(true)
                    }
                    "switchToAnalysis" -> {
                        val contactData = call.arguments as? Map<String, Any>
                        switchOverlayView("analysis", contactData)
                        result.success(true)
                    }
                    "switchToEdit" -> {
                        switchOverlayView("edit")
                        result.success(true)
                    }
                    "switchToBubble" -> {
                        switchOverlayView("bubble")
                        result.success(true)
                    }
                    "switchContacts" -> {
                        switchOverlayView("contacts")
                        result.success(true)
                    }
                    "switchAnalysis" -> {
                        val contactData = call.arguments as? Map<String, Any>
                        switchOverlayView("analysis", contactData)
                        result.success(true)
                    }
                    "switchEdit" -> {
                        switchOverlayView("edit")
                        result.success(true)
                    }
                    "switchBubble" -> {
                        switchOverlayView("bubble")
                        result.success(true)
                    }
                    "closeOverlay" -> {
                        hideNativeOverlay()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
            
            Log.d("MainActivity", "Overlay Flutter engine created successfully")
        } catch (e: Exception) {
            Log.e("MainActivity", "Error creating overlay Flutter engine", e)
        }
    }

    private fun switchOverlayView(viewType: String, data: Map<String, Any>? = null) {
        try {
            Log.d("MainActivity", "switchOverlayView called with viewType: $viewType")
            
            // Determine the size based on view type
            val (width, height) = when (viewType) {
                "bubble" -> Pair(200, 200)
                "contacts" -> Pair(1000, 1000)
                "analysis" -> Pair(1000, 1000)
                "edit" -> Pair(1000, 1000)
                else -> Pair(400, 550)
            }
            
            // Update overlay size
            params?.width = width
            params?.height = height
            windowManager?.updateViewLayout(overlayView, params)
            
            // Clear current overlay content
            (overlayView as? FrameLayout)?.removeAllViews()
            
            // Send view switch message to Flutter overlay
            overlayCommChannel?.invokeMethod("setOverlayView", mapOf(
                "viewType" to viewType,
                "data" to data
            ))
            
            // Create and add Flutter view
            createFlutterOverlayView(overlayView as FrameLayout, viewType, data)
            
            // Update state tracking
            currentOverlayView = viewType
            isExpanded = viewType != "bubble"
            
            Log.d("MainActivity", "Successfully switched overlay view to: $viewType with size ${width}x${height}")
            
        } catch (e: Exception) {
            Log.e("MainActivity", "Error switching overlay view", e)
        }
    }



    private fun createFlutterOverlayView(container: FrameLayout, viewType: String, data: Map<String, Any>? = null) {
        try {
            // Create Flutter engine if not exists
            if (overlayFlutterEngine == null) {
                createOverlayFlutterEngine()
                // Wait a bit for the engine to initialize
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    setupFlutterView(container, viewType, data)
                }, 500)
            } else {
                setupFlutterView(container, viewType, data)
            }
            
        } catch (e: Exception) {
            Log.e("MainActivity", "Error creating Flutter overlay view", e)
        }
    }
    
    private fun setupFlutterView(container: FrameLayout, viewType: String, data: Map<String, Any>? = null) {
        try {
            // Detach previous Flutter view if exists
            overlayFlutterView?.detachFromFlutterEngine()
            
            // Create new Flutter view
            overlayFlutterView = FlutterView(this@MainActivity)
            overlayFlutterView?.attachToFlutterEngine(overlayFlutterEngine!!)
            
            // For bubble view, add Flutter view and a transparent drag overlay
            if (viewType == "bubble") {
                container.addView(overlayFlutterView, FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
                ))
                
                // Add transparent drag overlay on top for bubble dragging
                val dragOverlay = createBubbleDragOverlay()
                container.addView(dragOverlay)
            } else {
                // For expanded views, create a drag handle at the top
                val dragHandle = createDragHandle()
                container.addView(dragHandle)
                
                // Add Flutter view below the drag handle
                val flutterParams = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
                ).apply {
                    topMargin = 40 // Space for drag handle
                }
                container.addView(overlayFlutterView, flutterParams)
            }
            
            // Send initial view configuration after a short delay to ensure Flutter is ready
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                overlayCommChannel?.invokeMethod("setOverlayView", mapOf(
                    "viewType" to viewType,
                    "data" to data
                ))
            }, 200)
            
            Log.d("MainActivity", "Flutter overlay view setup complete: $viewType")
            
        } catch (e: Exception) {
            Log.e("MainActivity", "Error setting up Flutter overlay view", e)
        }
    }
    
    private fun createDragHandle(): View {
        val dragHandle = View(this@MainActivity).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                40
            ).apply {
                gravity = Gravity.TOP
            }
            setBackgroundColor(0x88000000.toInt()) // Semi-transparent dark background
        }
        
        // Add drag functionality specifically to the drag handle
        dragHandle.setOnTouchListener { _, event ->
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
                    
                    if (!isDragging && (Math.abs(deltaX) > touchSlop || Math.abs(deltaY) > touchSlop)) {
                        isDragging = true
                    }
                    
                    if (isDragging) {
                        val newX = initialX + deltaX.toInt()
                        val newY = initialY + deltaY.toInt()
                        
                        val overlayWidth = params?.width ?: 400
                        val overlayHeight = params?.height ?: 600
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
                        saveOverlayPosition(params?.x ?: 0, params?.y ?: 0)
                        Log.d("MainActivity", "Overlay dragged via handle to (${params?.x}, ${params?.y})")
                        isDragging = false
                    }
                    true
                }
                else -> false
            }
        }
        
        return dragHandle
    }
    
    private fun createBubbleDragOverlay(): View {
        val dragOverlay = View(this@MainActivity).apply {
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            setBackgroundColor(0x00000000) // Completely transparent
        }
        
        var longPressDetected = false
        val longPressHandler = android.os.Handler(android.os.Looper.getMainLooper())
        val longPressRunnable = Runnable {
            longPressDetected = true
            Log.d("MainActivity", "Long press detected - enabling drag mode")
        }
        
        dragOverlay.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    isDragging = false
                    longPressDetected = false
                    initialX = params?.x ?: 0
                    initialY = params?.y ?: 0
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    
                    // Start long press timer
                    longPressHandler.removeCallbacks(longPressRunnable)
                    longPressHandler.postDelayed(longPressRunnable, 500) // 500ms for long press
                    
                    false // Don't consume initially, let Flutter handle taps
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = event.rawX - initialTouchX
                    val deltaY = event.rawY - initialTouchY
                    
                    // Check if user has moved finger enough to be considered dragging OR long press was detected
                    if (!isDragging && (longPressDetected || (Math.abs(deltaX) > touchSlop || Math.abs(deltaY) > touchSlop))) {
                        isDragging = true
                        longPressHandler.removeCallbacks(longPressRunnable)
                        Log.d("MainActivity", "Started dragging bubble")
                    }
                    
                    if (isDragging) {
                        val newX = initialX + deltaX.toInt()
                        val newY = initialY + deltaY.toInt()
                        
                        val overlayWidth = params?.width ?: 200
                        val overlayHeight = params?.height ?: 200
                        val screenWidth = getScreenWidth()
                        val screenHeight = getScreenHeight()
                        
                        params?.x = Math.max(0, Math.min(newX, screenWidth - overlayWidth))
                        params?.y = Math.max(0, Math.min(newY, screenHeight - overlayHeight))
                        
                        windowManager?.updateViewLayout(overlayView, params)
                        true // Consume the event when dragging
                    } else {
                        false // Let Flutter handle the event
                    }
                }
                MotionEvent.ACTION_UP -> {
                    longPressHandler.removeCallbacks(longPressRunnable)
                    
                    if (isDragging) {
                        // Snap to side for bubble view
                        val snappedX = snapToSide(params?.x ?: 0)
                        params?.x = snappedX
                        windowManager?.updateViewLayout(overlayView, params)
                        
                        // Save position
                        saveOverlayPosition(params?.x ?: 0, params?.y ?: 0)
                        
                        Log.d("MainActivity", "Bubble dragged and snapped to (${params?.x}, ${params?.y})")
                        isDragging = false
                        true // Consume the event
                    } else {
                        false // Let Flutter handle taps
                    }
                }
                MotionEvent.ACTION_CANCEL -> {
                    longPressHandler.removeCallbacks(longPressRunnable)
                    if (isDragging) {
                        isDragging = false
                        true
                    } else {
                        false
                    }
                }
                else -> false
            }
        }
        
        return dragOverlay
    }

    private fun addDragFunctionality(view: View) {
        val gestureDetector = android.view.GestureDetector(this, object : android.view.GestureDetector.SimpleOnGestureListener() {
            override fun onSingleTapUp(e: MotionEvent): Boolean {
                // Allow single taps to pass through to Flutter
                return false
            }
            
            override fun onLongPress(e: MotionEvent) {
                // Handle long press for dragging or other functionality
                Log.d("MainActivity", "Long press detected on overlay")
            }
        })
        
        view.setOnTouchListener { _, event ->
            // Let gesture detector handle taps and long presses first
            gestureDetector.onTouchEvent(event)
            
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    isDragging = false
                    initialX = params?.x ?: 0
                    initialY = params?.y ?: 0
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    false // Don't consume the event yet, let Flutter handle it
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = event.rawX - initialTouchX
                    val deltaY = event.rawY - initialTouchY
                    
                    // Check if user has moved finger enough to be considered dragging
                    if (!isDragging && (Math.abs(deltaX) > touchSlop || Math.abs(deltaY) > touchSlop)) {
                        isDragging = true
                        Log.d("MainActivity", "Started dragging overlay")
                    }
                    
                    if (isDragging) {
                        val newX = initialX + deltaX.toInt()
                        val newY = initialY + deltaY.toInt()
                        
                        // Constrain to screen boundaries
                        val overlayWidth = params?.width ?: 200
                        val overlayHeight = params?.height ?: 200
                        val screenWidth = getScreenWidth()
                        val screenHeight = getScreenHeight()
                        
                        params?.x = Math.max(0, Math.min(newX, screenWidth - overlayWidth))
                        params?.y = Math.max(0, Math.min(newY, screenHeight - overlayHeight))
                        
                        windowManager?.updateViewLayout(overlayView, params)
                        true // Consume the event when dragging
                    } else {
                        false // Let Flutter handle the event
                    }
                }
                MotionEvent.ACTION_UP -> {
                    if (isDragging) {
                        // Snap to side only for bubble view
                        if (currentOverlayView == "bubble") {
                            val snappedX = snapToSide(params?.x ?: 0)
                            params?.x = snappedX
                            windowManager?.updateViewLayout(overlayView, params)
                        }
                        
                        // Save position
                        saveOverlayPosition(params?.x ?: 0, params?.y ?: 0)
                        
                        Log.d("MainActivity", "Overlay dragged and positioned at (${params?.x}, ${params?.y})")
                        isDragging = false
                        true // Consume the event
                    } else {
                        false // Let Flutter handle taps
                    }
                }
                else -> false
            }
        }
    }

    // Native overlay management with Flutter content
    private fun showNativeOverlay() {
        try {
            if (overlayView != null) {
                Log.d("MainActivity", "Overlay already shown")
                return
            }

            windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

            // Configure window parameters - start with bubble size
            params = WindowManager.LayoutParams(
                200, // Start with bubble size
                200,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
            )

            // Get saved position or use default
            val (savedX, savedY) = getSavedOverlayPosition()
            params?.gravity = Gravity.TOP or Gravity.START
            params?.x = savedX
            params?.y = savedY
            
            Log.d("MainActivity", "Setting overlay position to ($savedX, $savedY)")

            // Create container for overlay content
            val container = FrameLayout(this@MainActivity)
            overlayView = container
            
            // Initialize Flutter engine
            createOverlayFlutterEngine()
            
            // Start with bubble view after a short delay to ensure Flutter engine is ready
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                switchOverlayView("bubble")
            }, 300)

            windowManager?.addView(overlayView, params)
            isOverlayFocusable = false
            isExpanded = false
            
            Log.d("MainActivity", "Native overlay with Flutter content shown")
            Log.d("MainActivity", "Position: x=${params?.x}, y=${params?.y}")
            Log.d("MainActivity", "Size: ${params?.width}x${params?.height}")

        } catch (e: Exception) {
            Log.e("MainActivity", "Error showing native overlay", e)
        }
    }





    private fun hideNativeOverlay() {
        try {
            if (overlayView != null && windowManager != null) {
                windowManager?.removeView(overlayView)
                overlayView = null
                windowManager = null
                params = null
                
                // Clean up Flutter overlay components
                overlayFlutterView?.detachFromFlutterEngine()
                overlayFlutterView = null
                overlayFlutterEngine?.destroy()
                overlayFlutterEngine = null
                overlayCommChannel = null
                
                isOverlayFocusable = false
                isExpanded = false
                currentOverlayView = "bubble"
                Log.d("MainActivity", "Native overlay hidden and Flutter engine cleaned up")
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

            // Switch to contacts view (expanded state)
            switchOverlayView("contacts")
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

            // Switch back to bubble view (collapsed state)
            switchOverlayView("bubble")
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
