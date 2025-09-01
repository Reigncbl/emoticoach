//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<app_links/AppLinksIosPlugin.h>)
#import <app_links/AppLinksIosPlugin.h>
#else
@import app_links;
#endif

#if __has_include(<desktop_webview_auth/DesktopWebviewAuthPlugin.h>)
#import <desktop_webview_auth/DesktopWebviewAuthPlugin.h>
#else
@import desktop_webview_auth;
#endif

#if __has_include(<device_info_plus/FPPDeviceInfoPlusPlugin.h>)
#import <device_info_plus/FPPDeviceInfoPlusPlugin.h>
#else
@import device_info_plus;
#endif

#if __has_include(<firebase_auth/FLTFirebaseAuthPlugin.h>)
#import <firebase_auth/FLTFirebaseAuthPlugin.h>
#else
@import firebase_auth;
#endif

#if __has_include(<firebase_core/FLTFirebaseCorePlugin.h>)
#import <firebase_core/FLTFirebaseCorePlugin.h>
#else
@import firebase_core;
#endif

#if __has_include(<flutter_native_splash/FlutterNativeSplashPlugin.h>)
#import <flutter_native_splash/FlutterNativeSplashPlugin.h>
#else
@import flutter_native_splash;
#endif

#if __has_include(<google_sign_in_ios/FLTGoogleSignInPlugin.h>)
#import <google_sign_in_ios/FLTGoogleSignInPlugin.h>
#else
@import google_sign_in_ios;
#endif

#if __has_include(<webview_flutter_wkwebview/WebViewFlutterPlugin.h>)
#import <webview_flutter_wkwebview/WebViewFlutterPlugin.h>
#else
@import webview_flutter_wkwebview;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [AppLinksIosPlugin registerWithRegistrar:[registry registrarForPlugin:@"AppLinksIosPlugin"]];
  [DesktopWebviewAuthPlugin registerWithRegistrar:[registry registrarForPlugin:@"DesktopWebviewAuthPlugin"]];
  [FPPDeviceInfoPlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"FPPDeviceInfoPlusPlugin"]];
  [FLTFirebaseAuthPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseAuthPlugin"]];
  [FLTFirebaseCorePlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTFirebaseCorePlugin"]];
  [FlutterNativeSplashPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterNativeSplashPlugin"]];
  [FLTGoogleSignInPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTGoogleSignInPlugin"]];
  [WebViewFlutterPlugin registerWithRegistrar:[registry registrarForPlugin:@"WebViewFlutterPlugin"]];
}

@end
