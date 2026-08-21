import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class StripeConnectPage extends StatefulWidget {
  const StripeConnectPage({super.key});

  @override
  State<StripeConnectPage> createState() => _StripeConnectPageState();
}

class _StripeConnectPageState extends State<StripeConnectPage>
    with WidgetsBindingObserver {
  static const _pink = Color(0xFFFF3366);
  static const _orange = Color(0xFFFF8C00);
  static const _backendUrl = 'http://72.61.254.215:3000';

  bool _loading = true;
  bool _connecting = false;
  String? _stripeAccountId;
  bool _detailsSubmitted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAccountStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Auto-refresh when user returns to the app from the Stripe browser
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAccountStatus();
    }
  }

  Future<void> _loadAccountStatus() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('cafeterias')
          .doc(uid)
          .get();

      final accountId =
          doc.data()?['stripeAccountId'] as String?;

      bool submitted = false;
      if (accountId != null) {
        // Check actual Stripe account status
        final response = await http.post(
          Uri.parse('$_backendUrl/account-status'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'accountId': accountId}),
        );
        if (response.statusCode == 200) {
          submitted =
              jsonDecode(response.body)['detailsSubmitted'] as bool? ??
                  false;
        }
      }

      if (mounted) {
        setState(() {
          _stripeAccountId = accountId;
          _detailsSubmitted = submitted;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connectStripe() async {
    setState(() => _connecting = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final uid = user.uid;

      final response = await http.post(
        Uri.parse('$_backendUrl/create-account-link'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cafeteriaId': uid,
          'email': user.email,
          if (_stripeAccountId != null) 'accountId': _stripeAccountId,
        }),
      );

      if (response.statusCode != 200) {
        throw jsonDecode(response.body)['error'] ?? 'Server error';
      }

      final data = jsonDecode(response.body);
      final accountId = data['accountId'] as String;
      final url = data['url'] as String;

      // Save accountId so we can regenerate the link if needed
      await FirebaseFirestore.instance
          .collection('cafeterias')
          .doc(uid)
          .update({'stripeAccountId': accountId});

      if (mounted) setState(() => _stripeAccountId = accountId);

      final uri = Uri.parse(url);
      if (!await canLaunchUrl(uri)) {
        throw 'Could not open browser. Please try again.';
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Color(0xFF1A1A1A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'BANK ACCOUNT',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: Color(0xFF1A1A1A),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_pink),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 28),
                    _buildInfoCard(),
                    const Spacer(),
                    _buildConnectButton(),
                    const SizedBox(height: 12),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline,
                            size: 13, color: Color(0xFF9B9B9B)),
                        SizedBox(width: 5),
                        Text(
                          'Secured by Stripe',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF9B9B9B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusCard() {
    // Three states: not connected / incomplete / connected
    final Color gradientStart;
    final Color gradientEnd;
    final IconData icon;
    final String title;
    final String subtitle;

    if (_stripeAccountId == null) {
      gradientStart = _pink;
      gradientEnd = _orange;
      icon = Icons.account_balance_outlined;
      title = 'No Bank Account';
      subtitle =
          'Connect your bank account to receive payments when meals are delivered.';
    } else if (!_detailsSubmitted) {
      gradientStart = const Color(0xFFF5A623);
      gradientEnd = const Color(0xFFFF8C00);
      icon = Icons.warning_amber_outlined;
      title = 'Setup Incomplete';
      subtitle =
          'You started setup but did not finish. Tap below to complete your bank account details.';
    } else {
      gradientStart = const Color(0xFF43A047);
      gradientEnd = const Color(0xFF66BB6A);
      icon = Icons.check_circle_outline;
      title = 'Bank Account Connected';
      subtitle =
          'You will receive payments automatically when meals are delivered.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient:
            LinearGradient(colors: [gradientStart, gradientEnd]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradientStart.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _infoRow(Icons.payments_outlined,
              'Payments sent automatically when you mark a meal as delivered'),
          const Divider(height: 20, color: Color(0xFFF0F0F0)),
          _infoRow(Icons.security_outlined,
              'Your bank details are handled securely by Stripe'),
          const Divider(height: 20, color: Color(0xFFF0F0F0)),
          _infoRow(Icons.schedule_outlined,
              'Funds typically arrive in your bank within 2 business days'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF9B9B9B)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF9B9B9B))),
        ),
      ],
    );
  }

  Widget _buildConnectButton() {
    String label;
    if (_stripeAccountId == null) {
      label = 'CONNECT BANK ACCOUNT';
    } else if (!_detailsSubmitted) {
      label = 'COMPLETE SETUP';
    } else {
      label = 'UPDATE BANK ACCOUNT';
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: _connecting
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_pink),
              ),
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_pink, _orange]),
                borderRadius: BorderRadius.circular(27),
              ),
              child: ElevatedButton(
                onPressed: _connectStripe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27)),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
    );
  }
}
