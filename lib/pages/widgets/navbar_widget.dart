import 'package:flutter/material.dart';
import 'package:capri/core/Color/Colors.dart';

class CommonNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavigationBarItem> items;

  const CommonNavbar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Renkler.kahveTon,
      unselectedItemColor: Colors.grey,
      items: items,
    );
  }
}
