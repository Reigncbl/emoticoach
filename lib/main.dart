import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer';
import 'dart:async';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home.dart';
import 'screens/overlay_page.dart';
import 'screens/profile.dart';
import 'screens/overlays/overlay_ui.dart';
import "screens/learning/scenario_screen.dart";
import 'widgets/bottom_nav_bar.dart';
import 'controllers/app_monitor_controller.dart';
import 'services/session_service.dart';
import 'utils/overlay_stats_tracker.dart';
import 'package:firebase_core/firebase_core.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: OverlayUI()),
  );
}

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text("Learn Screen")));
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Fixed: Only initialize Firebase if it hasn't been initialized yet

  // Initialize overlay statistics tracking
  try {
    log('🔧 Initializing overlay statistics tracker...');
    await OverlayStatsTracker.initialize().timeout(
      Duration(seconds: 10),
      onTimeout: () =>
          throw TimeoutException('Statistics initialization timed out'),
    );
    log('✅ Overlay statistics tracker initialized successfully');
  } catch (e) {
    log('⚠️ Failed to initialize overlay statistics tracker: $e');
    // Don't block app startup for statistics issues
  }

  _setupGlobalMethodChannel();
  runApp(const MyApp());
}

void _setupGlobalMethodChannel() {
  const MethodChannel overlayChannel = MethodChannel(
    'emoticoach_overlay_channel',
  );

  overlayChannel.setMethodCallHandler((call) async {
    log('Global method channel received call: ${call.method}');
    log('Call arguments: ${call.arguments}');

    if (call.method == 'showOverlay') {
      log('Triggering overlay from global method channel');
      try {
        // Add a delay to ensure everything is ready
        await Future.delayed(const Duration(milliseconds: 200));

        final appMonitor = AppMonitorController();

        // Ensure the overlay is enabled before triggering
        if (appMonitor.overlayEnabled) {
          await appMonitor.triggerOverlay();
          log('✅ Overlay triggered successfully!');
          return {'success': true, 'message': 'Overlay triggered'};
        } else {
          log('⚠️ Overlay is disabled, not showing');
          return {'success': false, 'error': 'Overlay is disabled'};
        }
      } catch (e) {
        log('❌ Error triggering overlay: $e');
        log('Error stack trace: ${StackTrace.current}');
        return {'success': false, 'error': e.toString()};
      }
    }

    return {'success': false, 'error': 'Unknown method: ${call.method}'};
  });

  log('✅ Global method channel set up successfully');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [routeObserver],
      debugShowCheckedModeBanner: false,
      title: 'Emoticoach',
      theme: ThemeData(primarySwatch: Colors.blue, fontFamily: 'OpenSans'),
      home: FutureBuilder<bool>(
        future: SimpleSessionService.isLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // If logged in, go to home. Otherwise, show onboarding
          return snapshot.data == true
              ? const MainScreen()
              : OnboardingScreen();
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  // final AppMonitorController _appMonitor = AppMonitorController(); // Commented out app monitoring

  final List<Widget> _pages = const [
    HomePage(), // index 0
    OverlayScreen(), // index 1
    LearningScreen(), // index 2
    ProfileScreen(), // index 3
  ];

  // Method to change the current index from other widgets
  void changeIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    // _initializeAppMonitoring(); // Commented out app monitoring
  }

  // Commented out app monitoring initialization
  /*
  Future<void> _initializeAppMonitoring() async {
    try {
      log('🚀 Initializing app monitoring...');

      // Check if auto-launch is enabled before starting monitoring
      if (_appMonitor.overlayEnabled) {
        await _appMonitor.startMonitoring();
        log('✅ App monitoring started successfully');
      } else {
        log('⚠️ Overlay disabled, skipping monitoring initialization');
      }
    } catch (e) {
      log('❌ Error initializing app monitoring: $e');
    }
  }
  */

  @override
  void dispose() {
    // _appMonitor.dispose(); // Commented out app monitoring disposal
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
