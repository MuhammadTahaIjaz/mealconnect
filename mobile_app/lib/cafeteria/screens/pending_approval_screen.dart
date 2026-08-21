import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class PendingApprovalScreen extends StatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  static const _pink = Color(0xFFFF3366);
  static const _orange = Color(0xFFFF8C00);

  late final StreamSubscription<DocumentSnapshot> _statusSub;
  StreamSubscription<User?>? _authSub;
  bool _navigating = false;
  bool _authInitialSkipped = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!_authInitialSkipped) { _authInitialSkipped = true; return; }
      if (user == null && mounted) _showAccountDeletedDialog();
    });

    _statusSub = FirebaseFirestore.instance
        .collection('cafeterias')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (_navigating || !mounted) return;
      final status =
          (doc.data()?['accountStatus'] as String?) ?? 'pending';
      if (status == 'approved') {
        _navigating = true;
        Navigator.pushReplacementNamed(context, '/cafeteria-home');
      }
    });
  }

  @override
  void dispose() {
    _statusSub.cancel();
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

  Future<void> _signOut() async {
    _authSub?.cancel();
    _authSub = null;
    await AuthService.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/type-selection');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Icon
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_pink, _orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              const Text(
                'Cafeteria Under Review',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 14),

              // Message
              const Text(
                'Your cafeteria registration has been received. '
                'You will get an email once the school admin approves '
                'your account. This screen will update automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF9B9B9B),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),

              // Live indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF43A047),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Listening for approval...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9B9B9B),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // Sign out
              GestureDetector(
                onTap: _signOut,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9B9B9B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
