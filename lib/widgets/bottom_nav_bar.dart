import '../utils/colors.dart';

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

  Widget _buildIcon(String iconData, int index) {
    final isSelected = currentIndex == index;
    final color = isSelected ? kPrimaryBlue : kBlack;

    return Iconify(iconData, size: 30, color: color);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: kBlack.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        selectedItemColor: kPrimaryBlue,
        unselectedItemColor: kBlack,
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        onTap: (index) => _handleTap(context, index),
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        items: [
          BottomNavigationBarItem(
            icon: _buildIcon(Ic.outline_home, 0),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon(Ic.outline_layers, 1),
            label: 'Coach',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon(Ic.outline_menu_book, 2),
            label: 'Learn',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon(Ic.person_outline, 3),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
