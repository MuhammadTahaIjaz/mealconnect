import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'active_orders_page.dart';
import 'meal_management_page.dart';
import 'cafeteria_history_page.dart';
import 'cafeteria_notifications_page.dart';
import 'cafeteria_settings_page.dart';
import 'stripe_connect_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  late final List<Widget> _pages;
  StreamSubscription<User?>? _authSub;
  bool _authInitialSkipped = false;
  bool _stripeComplete = true; // assume complete until checked

  @override
  void initState() {
    super.initState();
    _pages = [
      const ActiveOrdersPage(),
      const MealManagementPage(),
      const CafeteriaHistoryPage(),
      const CafeteriaNotificationsPage(),
      CafeteriaSettingsPage(onBeforeSignOut: () { _authSub?.cancel(); _authSub = null; }),
    ];
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!_authInitialSkipped) { _authInitialSkipped = true; return; }
      if (user == null && mounted) _showAccountDeletedDialog();
    });
    _loadStripeStatus();
  }

  Future<void> _loadStripeStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('cafeterias')
          .doc(uid)
          .get();
      final accountId = doc.data()?['stripeAccountId'] as String?;
      if (mounted) setState(() => _stripeComplete = accountId != null);
    } catch (_) {
      if (mounted) setState(() => _stripeComplete = true);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _showAccountDeletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Account Removed',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Your account no longer exists. Please contact your school admin for more information.',
          style: TextStyle(fontFamily: 'Poppins', color: Color(0xFF9B9B9B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext, rootNavigator: true)
                .pushNamedAndRemoveUntil('/type-selection', (_) => false),
            child: const Text(
              'OK',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFFFF3366),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (!_stripeComplete) _buildStripeBanner(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildStripeBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StripeConnectPage()),
      ).then((_) => _loadStripeStatus()),
      child: Container(
        width: double.infinity,
        color: const Color(0xFFFFF8E1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: const [
              Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFF5A623), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Complete your bank account setup to receive payments.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8B6900)),
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Color(0xFFF5A623), size: 18),
            ],
          ),
        ),
      ),
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
