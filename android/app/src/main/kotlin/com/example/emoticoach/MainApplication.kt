package com.example.emoticoach

import android.app.Application
import android.os.Build
import android.util.Log
import android.webkit.WebView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        
        // Enable WebView debugging
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            WebView.setWebContentsDebuggingEnabled(true)
        }
        
        // Initialize a temporary WebView to set up default WebView settings
        // This ensures all WebViews in the app (including EPUB viewer) have proper settings
        try {
            val webView = WebView(applicationContext)
            webView.settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                databaseEnabled = true
                allowFileAccess = true
                allowContentAccess = true
                // These settings are crucial for EPUB viewer to work properly with iframes
                javaScriptCanOpenWindowsAutomatically = true
                mediaPlaybackRequiresUserGesture = false
                
                // Allow access from file URLs (needed for local EPUB files)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
                    allowFileAccessFromFileURLs = true
                    allowUniversalAccessFromFileURLs = true
                }
                
                // Mixed content mode
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    mixedContentMode = android.webkit.WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
                }
            }
            webView.destroy()
            
            Log.d("MainApplication", "WebView default settings configured successfully")
        } catch (e: Exception) {
            Log.e("MainApplication", "Error configuring WebView settings: ${e.message}")
        }
    }
}
