import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int)? onTap;
  final List<Widget>? screens;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    this.onTap,
    this.screens,
  });

  void _handleTap(BuildContext context, int index) {
    if (onTap != null) {
      onTap!(index);
    }

    if (screens != null && index < screens!.length) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => screens![index]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color kPrimaryBlue = Color(0xFF3176F8);

    return BottomNavigationBar(
      selectedItemColor: kPrimaryBlue,
      unselectedItemColor: Colors.grey[600],
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: (index) => _handleTap(context, index),
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
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
    );
  }
}
