import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../parent/services/auth_service.dart' as parent_auth;
import '../../cafeteria/services/auth_service.dart' as cafeteria_auth;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _imageSlideAnimation;

  String _nextRoute = '/type-selection';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );

    _imageSlideAnimation = Tween<double>(begin: 100.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    Future.wait([
      Future.delayed(const Duration(milliseconds: 2500)),
      _resolveRoute(),
    ]).then((_) {
      if (mounted) Navigator.pushReplacementNamed(context, _nextRoute);
    });
  }

  Future<void> _resolveRoute() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _nextRoute = '/type-selection';
      return;
    }

    try {
      // Check the user's role to route them to the correct section
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 10));

      final role = (doc.data()?['role'] as String?) ?? '';

      if (role == 'cafeteria') {
        final status =
            await cafeteria_auth.AuthService.getCafeteriaStatus(user.uid);
        _nextRoute =
            status == 'approved' ? '/cafeteria-home' : '/cafeteria-pending';
      } else {
        // Parent flow
        final status =
            await parent_auth.AuthService.getAccountStatus(user.uid);
        if (status == 'approved') {
          final hasChildren =
              await parent_auth.AuthService.hasChildren(user.uid);
          _nextRoute =
              hasChildren ? '/parent-home' : '/parent-children-details';
        } else {
          _nextRoute = '/parent-pending';
        }
      }
    } catch (_) {
      _nextRoute = '/type-selection';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFF3366),
              Color(0xFFFF6633),
              Color(0xFFFF8C00),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: MediaQuery.of(context).size.height * 0.38,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'MealConnect',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 42,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tasty & Healthy',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                          color: Colors.white.withValues(alpha: 0.9),
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _imageSlideAnimation,
              builder: (context, child) {
                return Positioned(
                  bottom: -_imageSlideAnimation.value,
                  left: -40,
                  right: -40,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: child,
                  ),
                );
              },
              child: Image.asset(
                'assets/images/splash_food.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                    height: 300,
                    child: Center(
                      child: Text('🍽️', style: TextStyle(fontSize: 80)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
