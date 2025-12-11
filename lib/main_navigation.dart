import 'package:flutter/material.dart';

import 'AccountScreen.dart';
import 'AttendanceScreen.dart';
import 'LeaveScreen.dart';
import 'TaskListScreen.dart';
import 'home_screen2.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen2(),       // 0
    const AttendanceScreen(),  // 1
    const TaskListScreen(),    // 2 (To-Do List)
    const LeaveScreen(),       // 3
    const AccountScreen(),     // 4
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        top: false,
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: _buildModernNavBar(),
    );
  }

  // ---------------------- BOTTOM NAV BAR UI ----------------------
  Widget _buildModernNavBar() {
    return Container(
      padding: const EdgeInsets.only(top: 0),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),   // ⭐ MATCHES YOUR SCREENSHOT
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        currentIndex: _currentIndex,

        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.grey.shade500,

        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),

        onTap: (index) {
          setState(() => _currentIndex = index);
        },

        items: [
          _navItem(Icons.home_outlined, "Home", 0),
          _navItem(Icons.calendar_month, "Attendance", 1),
          _navItem(Icons.list_alt_outlined, "To-Do", 2),
          _navItem(Icons.person_outline, "Leave", 3),
          _navItem(Icons.account_circle_outlined, "Account", 4),
        ],
      ),
    );
  }

  // ---------------------- ICON STYLE ----------------------
  BottomNavigationBarItem _navItem(IconData icon, String label, int index) {
    final bool isActive = _currentIndex == index;

    return BottomNavigationBarItem(
      label: label,
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: isActive
            ? BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        )
            : null,
        child: Icon(
          icon,
          size: isActive ? 26 : 22,
          color: isActive ? Colors.blue.shade700 : Colors.grey.shade500,
        ),
      ),
    );
  }
}
