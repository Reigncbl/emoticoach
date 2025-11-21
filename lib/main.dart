import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer';
import 'dart:async';
import 'dart:isolate';
import 'dart:ui' as ui;
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/home.dart';
import 'screens/overlay_page.dart';
import 'screens/profile.dart';
import 'screens/overlays/overlay_ui.dart';
import "screens/learning/scenario_screen.dart";
import 'widgets/bottom_nav_bar.dart';
import 'services/session_service.dart';
import 'utils/overlay_stats_tracker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'utils/overlay_clipboard_helper.dart';
import 'services/local_notification_service.dart';
import 'firebase_options.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  ui.DartPluginRegistrant.ensureInitialized();
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

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
  );

  await LocalNotificationService.initialize();

  _registerOverlayClipboardPort();

  try {
    await OverlayStatsTracker.initialize().timeout(
      Duration(seconds: 10),
      onTimeout: () =>
          throw TimeoutException('Statistics initialization timed out'),
    );
  } catch (e) {
    log('Failed to initialize overlay statistics tracker: $e');
  }

  runApp(const MyApp());
}

void _registerOverlayClipboardPort() {
  final existing = ui.IsolateNameServer.lookupPortByName(
    overlayClipboardPortName,
  );
  if (existing != null) {
    ui.IsolateNameServer.removePortNameMapping(overlayClipboardPortName);
  }

  final receivePort = ReceivePort();
  ui.IsolateNameServer.registerPortWithName(
    receivePort.sendPort,
    overlayClipboardPortName,
  );

  receivePort.listen((message) async {
    if (message is Map && message['action'] == 'copy') {
      final text = message['text'] as String? ?? '';
      bool success = false;
      try {
        await Clipboard.setData(ClipboardData(text: text));
        success = true;
      } catch (_) {
        success = false;
      }

      final SendPort? replyPort = message['replyPort'] as SendPort?;
      if (replyPort != null) {
        replyPort.send({'success': success});
      }
    }
  });
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
  }

  @override
  void dispose() {
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
