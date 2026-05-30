import 'package:flutter/material.dart';
import 'active_orders_page.dart';
import 'meal_management_page.dart';
import 'cafeteria_history_page.dart';
import 'cafeteria_notifications_page.dart';
import 'cafeteria_settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    ActiveOrdersPage(),
    MealManagementPage(),
    CafeteriaHistoryPage(),
    CafeteriaNotificationsPage(),
    CafeteriaSettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.pending_actions_outlined,
                  Icons.pending_actions),
              _navItem(1, Icons.restaurant_menu_outlined,
                  Icons.restaurant_menu),
              _navItem(2, Icons.receipt_long_outlined,
                  Icons.receipt_long),
              _navItem(3, Icons.notifications_outlined,
                  Icons.notifications),
              _navItem(4, Icons.settings_outlined, Icons.settings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData outlinedIcon, IconData filledIcon) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: isActive
                    ? const [Color(0xFFFF3366), Color(0xFFFF8C00)]
                    : [Colors.grey.shade400, Colors.grey.shade400],
              ).createShader(bounds),
              child: Icon(
                isActive ? filledIcon : outlinedIcon,
                size: 26,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: isActive ? 20 : 0,
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        colors: [Color(0xFFFF3366), Color(0xFFFF8C00)],
                      )
                    : null,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
