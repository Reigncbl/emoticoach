import 'dart:io';
import 'dart:ui';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart';
class WebViewHelper {
  static WebViewController createOptimizedController() {
    final controller = WebViewController();
    
    // Basic configuration
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..enableZoom(false);
    
    // Platform-specific optimizations
    if (Platform.isAndroid) {
      // Android-specific WebView settings
      controller.setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36'
      );
    } else if (Platform.isIOS) {
      // iOS-specific WebView settings
      controller.setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1'
      );
    }
    
    return controller;
  }
  
  static NavigationDelegate createStableNavigationDelegate({
    required Function(String) onPageStarted,
    required Function(String) onPageFinished,
    required Function(WebResourceError) onWebResourceError,
    required Function(HttpResponseError) onHttpError,
  }) {
    return NavigationDelegate(
      onPageStarted: (String url) {
        if (kDebugMode) {
          print('WebView: Page started loading - $url');
        }
        onPageStarted(url);
      },
      onPageFinished: (String url) {
        if (kDebugMode) {
          print('WebView: Page finished loading - $url');
        }
        onPageFinished(url);
      },
      onWebResourceError: (WebResourceError error) {
        if (kDebugMode) {
          print('WebView: Resource error - ${error.description} (${error.errorCode})');
        }
        
        // Only handle critical errors that should stop the process
        if (_isCriticalError(error)) {
          onWebResourceError(error);
        }
      },
      onHttpError: (HttpResponseError error) {
        if (kDebugMode) {
          print('WebView: HTTP error - ${error.response?.statusCode}');
        }
        onHttpError(error);
      },
      onNavigationRequest: (NavigationRequest request) {
        // Allow all navigation for reCAPTCHA
        if (request.url.contains('google.com') || 
            request.url.contains('gstatic.com') ||
            request.url.contains('recaptcha') ||
            request.url.startsWith('data:') ||
            request.url.startsWith('about:')) {
          return NavigationDecision.navigate;
        }
        
        // Block other external navigation
        return NavigationDecision.prevent;
      },
    );
  }
  
  static bool _isCriticalError(WebResourceError error) {
    // Only treat these as critical errors that should stop the WebView
    switch (error.errorType) {
      case WebResourceErrorType.hostLookup:
      case WebResourceErrorType.connect:
      case WebResourceErrorType.timeout:
        return true;
      default:
        return false;
    }
  }
  
  static String getOptimizedRecaptchaHtml(String siteKey) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Security Verification</title>
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        
        .container {
            background: white;
            border-radius: 16px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            padding: 32px;
            text-align: center;
            max-width: 400px;
            width: 100%;
            position: relative;
            overflow: hidden;
        }
        
        .container::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 4px;
            background: linear-gradient(90deg, #667eea, #764ba2);
        }
        
        .title {
            color: #2d3748;
            font-size: 24px;
            font-weight: 700;
            margin-bottom: 8px;
        }
        
        .subtitle {
            color: #718096;
            font-size: 16px;
            margin-bottom: 32px;
            line-height: 1.5;
        }
        
        #recaptcha-container {
            margin: 24px auto;
            min-height: 78px;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .loading {
            display: flex;
            align-items: center;
            gap: 12px;
            color: #4a5568;
            font-size: 16px;
        }
        
        .spinner {
            width: 20px;
            height: 20px;
            border: 2px solid #e2e8f0;
            border-top: 2px solid #667eea;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .security-info {
            background: linear-gradient(135deg, #e6fffa 0%, #f0fff4 100%);
            border: 1px solid #9ae6b4;
            border-radius: 12px;
            padding: 16px;
            margin-top: 24px;
            font-size: 14px;
            color: #2f855a;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        
        .error-state {
            background: linear-gradient(135deg, #fed7d7 0%, #feb2b2 100%);
            border: 1px solid #fc8181;
            color: #c53030;
        }
        
        .retry-btn {
            background: #667eea;
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            margin-top: 16px;
            transition: background 0.2s;
        }
        
        .retry-btn:hover {
            background: #5a67d8;
        }
    </style>
</head>
<body>
    <div class="container">
        <h2 class="title">🔐 Security Check</h2>
        <p class="subtitle">Please complete the verification to continue securely</p>
        
        <div id="recaptcha-container">
            <div class="loading" id="loading-indicator">
                <div class="spinner"></div>
                <span>Loading verification...</span>
            </div>
        </div>
        
        <div class="security-info" id="info-panel">
            <span>🛡️</span>
            <span>This verification helps protect your account from unauthorized access</span>
        </div>
    </div>

    <script>
        let widgetId = null;
        let isRendered = false;
        let retryCount = 0;
        const MAX_RETRIES = 3;
        
        // Global error tracking
        let hasError = false;
        
        function updateLoadingState(message, isError = false) {
            const indicator = document.getElementById('loading-indicator');
            const infoPanel = document.getElementById('info-panel');
            
            if (indicator) {
                if (isError) {
                    indicator.innerHTML = '<span style="color: #e53e3e;">⚠️ ' + message + '</span>';
                    if (retryCount < MAX_RETRIES) {
                        indicator.innerHTML += '<button class="retry-btn" onclick="retryLoad()">Retry</button>';
                    }
                } else {
                    indicator.innerHTML = '<div class="spinner"></div><span>' + message + '</span>';
                }
            }
            
            if (infoPanel && isError) {
                infoPanel.className = 'security-info error-state';
                infoPanel.innerHTML = '<span>⚠️</span><span>Verification failed. Please try again.</span>';
            }
        }
        
        function retryLoad() {
            retryCount++;
            hasError = false;
            updateLoadingState('Retrying verification...');
            
            // Clear any existing widgets
            const container = document.getElementById('recaptcha-container');
            container.innerHTML = '<div class="loading" id="loading-indicator"><div class="spinner"></div><span>Retrying verification...</span></div>';
            
            // Retry loading
            setTimeout(loadRecaptcha, 1000);
        }
        
        function onRecaptchaCallback(token) {
            console.log('reCAPTCHA completed successfully');
            
            if (token && token.length > 10) {
                // Send success to Flutter
                if (window.RecaptchaFlutter && window.RecaptchaFlutter.postMessage) {
                    RecaptchaFlutter.postMessage('token:' + token);
                } else {
                    console.error('Flutter communication channel not available');
                    updateLoadingState('Communication error', true);
                }
            } else {
                console.error('Invalid token received');
                updateLoadingState('Invalid verification token', true);
            }
        }

        function onRecaptchaError() {
            console.error('reCAPTCHA error occurred');
            hasError = true;
            updateLoadingState('Verification failed', true);
            
            if (window.RecaptchaFlutter && window.RecaptchaFlutter.postMessage) {
                RecaptchaFlutter.postMessage('error:Verification failed. Please try again.');
            }
        }

        function onRecaptchaExpired() {
            console.log('reCAPTCHA expired');
            updateLoadingState('Verification expired', true);
            
            if (window.RecaptchaFlutter && window.RecaptchaFlutter.postMessage) {
                RecaptchaFlutter.postMessage('error:Verification expired. Please try again.');
            }
        }

        function renderRecaptcha() {
            if (hasError || isRendered) {
                return;
            }
            
            console.log('Attempting to render reCAPTCHA...');
            
            if (typeof grecaptcha === 'undefined') {
                console.error('grecaptcha not available');
                updateLoadingState('Failed to load verification service', true);
                return;
            }

            try {
                const container = document.getElementById('recaptcha-container');
                if (!container) {
                    console.error('Container not found');
                    return;
                }
                
                // Clear loading indicator
                container.innerHTML = '';

                // Create widget container
                const widgetDiv = document.createElement('div');
                widgetDiv.id = 'recaptcha-widget-' + Date.now();
                container.appendChild(widgetDiv);

                // Render with delay to ensure DOM is ready
                setTimeout(() => {
                    if (hasError) return;
                    
                    try {
                        widgetId = grecaptcha.render(widgetDiv.id, {
                            'sitekey': '$siteKey',
                            'callback': onRecaptchaCallback,
                            'error-callback': onRecaptchaError,
                            'expired-callback': onRecaptchaExpired,
                            'theme': 'light',
                            'size': 'normal'
                        });
                        
                        console.log('reCAPTCHA rendered successfully with ID:', widgetId);
                        isRendered = true;
                        
                    } catch (renderError) {
                        console.error('Error during reCAPTCHA render:', renderError);
                        updateLoadingState('Failed to initialize verification', true);
                    }
                }, 300);

            } catch (error) {
                console.error('Error setting up reCAPTCHA:', error);
                updateLoadingState('Setup error occurred', true);
            }
        }

        function onRecaptchaLoad() {
            console.log('reCAPTCHA script loaded');
            
            if (typeof grecaptcha !== 'undefined' && grecaptcha.ready) {
                grecaptcha.ready(() => {
                    console.log('reCAPTCHA ready');
                    if (!hasError) {
                        renderRecaptcha();
                    }
                });
            } else {
                console.warn('grecaptcha.ready not available, using fallback');
                setTimeout(() => {
                    if (!hasError) {
                        renderRecaptcha();
                    }
                }, 1500);
            }
        }
        
        function loadRecaptcha() {
            // Prevent multiple script loads
            if (document.querySelector('script[src*="recaptcha"]')) {
                console.log('reCAPTCHA script already loaded');
                onRecaptchaLoad();
                return;
            }
            
            const script = document.createElement('script');
            script.src = 'https://www.google.com/recaptcha/api.js?onload=onRecaptchaLoad&render=explicit';
            script.async = true;
            script.defer = true;
            
            script.onerror = function() {
                console.error('Failed to load reCAPTCHA script');
                updateLoadingState('Failed to load verification service', true);
                
                if (window.RecaptchaFlutter && window.RecaptchaFlutter.postMessage) {
                    RecaptchaFlutter.postMessage('error:Network error. Please check your connection.');
                }
            };
            
            document.head.appendChild(script);
        }

        // Global error handlers
        window.addEventListener('error', function(e) {
            console.error('Global error:', e.error);
            if (!hasError && e.error && e.error.message) {
                hasError = true;
                updateLoadingState('Page error occurred', true);
            }
        });

        window.addEventListener('unhandledrejection', function(e) {
            console.error('Unhandled promise rejection:', e.reason);
            if (!hasError) {
                hasError = true;
                updateLoadingState('Network error occurred', true);
            }
        });

        // Initialize when page loads
        window.addEventListener('load', function() {
            console.log('Page loaded, initializing reCAPTCHA...');
            loadRecaptcha();
            
            // Fallback timeout
            setTimeout(function() {
                if (!isRendered && !hasError) {
                    console.error('reCAPTCHA failed to load within timeout');
                    updateLoadingState('Loading timeout. Please try again.', true);
                    
                    if (window.RecaptchaFlutter && window.RecaptchaFlutter.postMessage) {
                        RecaptchaFlutter.postMessage('error:Loading timeout. Please try again.');
                    }
                }
            }, 20000);
        });
    </script>
</body>
</html>
    ''';
  }
}