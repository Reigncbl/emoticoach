package com.example.emoticoach

import android.app.Application
import android.os.Build
import android.util.Log
import android.webkit.WebView
import com.google.firebase.FirebaseApp
import com.google.firebase.appcheck.FirebaseAppCheck
import com.google.firebase.appcheck.playintegrity.PlayIntegrityAppCheckProviderFactory

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        ensureFirebaseAppCheck()
        
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

    private fun ensureFirebaseAppCheck() {
        try {
            if (FirebaseApp.getApps(this).isEmpty()) {
                FirebaseApp.initializeApp(this)
            }
            val firebaseAppCheck = FirebaseAppCheck.getInstance()
            firebaseAppCheck.installAppCheckProviderFactory(
                PlayIntegrityAppCheckProviderFactory.getInstance()
            )
            Log.d("MainApplication", "Firebase App Check Play Integrity initialized")
        } catch (e: Exception) {
            Log.e("MainApplication", "Failed to initialize Firebase App Check", e)
        }
    }
}
