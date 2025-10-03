package com.example.emoticoach.overlay

import android.animation.ValueAnimator
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.util.DisplayMetrics
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.FrameLayout
import androidx.core.animation.doOnEnd
import androidx.core.app.NotificationCompat
import com.example.emoticoach.MainActivity
import com.example.emoticoach.R
import kotlin.math.abs
import kotlin.jvm.Volatile

class StickyBubbleService : Service() {

    companion object {
        private const val TAG = "StickyBubbleService"
        const val ACTION_SHOW_BUBBLE = "com.example.emoticoach.overlay.SHOW_BUBBLE"
        const val ACTION_HIDE_BUBBLE = "com.example.emoticoach.overlay.HIDE_BUBBLE"
        const val ACTION_STOP = "com.example.emoticoach.overlay.STOP"
        @Volatile
        var isServiceRunning: Boolean = false
        @Volatile
        var isBubbleVisible: Boolean = false
        @Volatile
        var lastAttachErrorMessage: String? = null
    }

    private var windowManager: WindowManager? = null
    private var bubbleView: FrameLayout? = null
    private lateinit var layoutParams: WindowManager.LayoutParams
    private var isBubbleAttached = false
    private var screenWidth: Int = 0
    private var screenHeight: Int = 0
    private val notificationId = 1005
    private val notificationChannelId = "emoticoach_overlay_bubble"

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service onCreate")
        isServiceRunning = true
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        startForegroundNotification()
        configureDisplayMetrics()
        createLayoutParams()
        createBubbleView()
        Log.d(TAG, "Service initialization complete")
    }

    private fun configureDisplayMetrics() {
        val metrics = DisplayMetrics()
        windowManager?.defaultDisplay?.getMetrics(metrics)
        screenWidth = metrics.widthPixels
        screenHeight = metrics.heightPixels
    }

    private fun createLayoutParams() {
        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT,
        )

        layoutParams.gravity = Gravity.TOP or Gravity.START
        layoutParams.x = 0
        layoutParams.y = screenHeight / 3
    }

    private fun createBubbleView() {
        if (bubbleView != null) return

        val inflater = LayoutInflater.from(this)
        val view = inflater.inflate(R.layout.layout_sticky_bubble, null)
        bubbleView = view as? FrameLayout
        Log.d(TAG, "Bubble view created")

        bubbleView?.setOnClickListener {
            Log.d(TAG, "Bubble tapped")
            hideBubble()
            launchAnalysisOverlay()
        }

        bubbleView?.setOnTouchListener(createDragTouchListener())
    }

    private fun ensureBubbleAttached() {
        if (isBubbleAttached) {
            isBubbleVisible = true
            return
        }

        if (bubbleView == null) {
            createBubbleView()
        }

        runCatching {
            windowManager?.addView(bubbleView, layoutParams)
            isBubbleAttached = true
            isBubbleVisible = true
            lastAttachErrorMessage = null
            Log.d(TAG, "Bubble attached")
        }.onFailure { error ->
            Log.e(TAG, "Failed to attach bubble", error)
            isBubbleAttached = false
            isBubbleVisible = false
            lastAttachErrorMessage = error.localizedMessage ?: error::class.java.simpleName
        }
    }

    private fun hideBubble() {
        if (!isBubbleAttached) {
            isBubbleVisible = false
            Log.d(TAG, "hideBubble called but bubble not attached")
            return
        }

        bubbleView?.let { view ->
            runCatching {
                windowManager?.removeView(view)
                Log.d(TAG, "Bubble removed")
            }.onFailure { error ->
                Log.e(TAG, "Failed to remove bubble", error)
                lastAttachErrorMessage = error.localizedMessage ?: error::class.java.simpleName
            }
        }
        isBubbleAttached = false
        isBubbleVisible = false
    }

    private fun createDragTouchListener(): View.OnTouchListener {
        return object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0f
            private var initialTouchY = 0f
            private var isDragging = false
            private val touchSlop = ViewConfiguration.get(this@StickyBubbleService).scaledTouchSlop

            override fun onTouch(v: View, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        isDragging = false
                        initialX = layoutParams.x
                        initialY = layoutParams.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val dx = (event.rawX - initialTouchX).toInt()
                        val dy = (event.rawY - initialTouchY).toInt()

                        if (!isDragging && (abs(dx) > touchSlop || abs(dy) > touchSlop)) {
                            isDragging = true
                        }

                        if (isDragging) {
                            layoutParams.x = initialX + dx
                            layoutParams.y = clampY(initialY + dy)
                            windowManager?.updateViewLayout(bubbleView, layoutParams)
                        }
                        return true
                    }
                    MotionEvent.ACTION_UP -> {
                        if (isDragging) {
                            snapToNearestEdge()
                            return true
                        }
                    }
                }
                return false
            }
        }
    }

    private fun clampY(targetY: Int): Int {
        val bubbleHeight = bubbleView?.height ?: 0
        val statusBarHeight = getStatusBarHeight()
        val minY = statusBarHeight
        val maxY = screenHeight - bubbleHeight - statusBarHeight
        return targetY.coerceIn(minY, maxY)
    }

    private fun snapToNearestEdge() {
        Log.d(TAG, "Snapping bubble to nearest edge")
        val bubbleWidth = bubbleView?.width ?: 0
        if (bubbleWidth == 0) return

        val currentCenterX = layoutParams.x + bubbleWidth / 2
        val targetX = if (currentCenterX < screenWidth / 2) 0 else screenWidth - bubbleWidth

        val animator = ValueAnimator.ofInt(layoutParams.x, targetX).apply {
            duration = 220
            interpolator = DecelerateInterpolator()
            addUpdateListener { animation ->
                layoutParams.x = animation.animatedValue as Int
                windowManager?.updateViewLayout(bubbleView, layoutParams)
            }
            doOnEnd {
                layoutParams.x = targetX
            }
        }
        animator.start()
    }

    private fun launchAnalysisOverlay() {
        Log.d(TAG, "Launching analysis overlay from bubble tap")
        val intent = Intent(this, MainActivity::class.java).apply {
            action = "SHOW_OVERLAY_ONLY"
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand action=${intent?.action}")
        isServiceRunning = true
        when (intent?.action) {
            ACTION_HIDE_BUBBLE -> hideBubble()
            ACTION_SHOW_BUBBLE -> ensureBubbleAttached()
            ACTION_STOP -> {
                hideBubble()
                stopSelf()
            }
            else -> ensureBubbleAttached()
        }
        Log.d(TAG, "onStartCommand complete: isBubbleVisible=$isBubbleVisible isServiceRunning=$isServiceRunning")
        return START_STICKY
    }

    override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
        super.onConfigurationChanged(newConfig)
        configureDisplayMetrics()
        snapToNearestEdge()
    }

    override fun onDestroy() {
        Log.d(TAG, "Service onDestroy")
        hideBubble()
        stopForeground(true)
        isServiceRunning = false
        isBubbleVisible = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun getStatusBarHeight(): Int {
        var result = 0
        val resourceId = resources.getIdentifier("status_bar_height", "dimen", "android")
        if (resourceId > 0) {
            result = resources.getDimensionPixelSize(resourceId)
        }
        return result
    }

    private fun startForegroundNotification() {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                notificationChannelId,
                "Emoticoach Overlay",
                NotificationManager.IMPORTANCE_MIN,
            ).apply {
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_SECRET
                description = "Keeps the Emoticoach floating bubble active"
            }
            manager?.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, notificationChannelId)
            .setContentTitle(getString(R.string.app_name))
            .setContentText(getString(R.string.app_name))
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setSilent(true)
            .build()

        startForeground(notificationId, notification)
    }
}
