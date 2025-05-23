import 'package:flutter/material.dart';
import 'screens/home.dart';
import 'screens/overlay.dart';

// Placeholder screens - replace with real implementations later
class LearnScreen extends StatelessWidget {
  const LearnScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text("Learn Screen")));
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text("Profile Screen")));
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Emoticoach',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(), // index 0
    OverlayScreen(), // index 1
    LearnScreen(), // index 2
    ProfileScreen(), // index 3
  ];

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
