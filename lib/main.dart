import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home.dart';
import 'screens/overlay_page.dart';
import 'screens/profile.dart';
import 'screens/overlays/overlay_ui.dart';
import 'controllers/app_monitor_controller.dart';
import 'services/session_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/learning/scenario_screen.dart';

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

  // Fixed: Only initialize Firebase if it hasn't been initialized yet
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    log('✅ Firebase initialized successfully');
  } else {
    log('⚠️ Firebase already initialized, skipping...');
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
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final AppMonitorController _appMonitor = AppMonitorController();

  final List<Widget> _pages = const [
    HomePage(), // index 0
    OverlayScreen(), // index 1
    LearningScreen(), // index 2
    ProfileScreen(), // index 3
  ];

  @override
  void initState() {
    super.initState();
    _initializeAppMonitoring();
  }

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

  @override
  void dispose() {
    _appMonitor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: const Color(0xFF3176F8),
        unselectedItemColor: Colors.grey[600],
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        showUnselectedLabels: true,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.layers_outlined),
            label: 'Overlay',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Learn',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
