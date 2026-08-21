import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'profile_page.dart';
import 'privacy_policy_page.dart';
import 'terms_conditions_page.dart';
import 'spending_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.onBeforeSignOut});

  final VoidCallback? onBeforeSignOut;

  static const _orange = Color(0xFFF5A623);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            const Text(
              'SETTINGS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 32),
            _buildItem(
              label: 'Profile',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProfilePage(onBeforeSignOut: onBeforeSignOut)),
              ),
            ),
            _buildDivider(),
            _buildItem(
              label: 'My Spending',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SpendingPage()),
              ),
            ),
            _buildDivider(),
            _buildItem(
              label: 'Privacy Policy',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyPage()),
              ),
            ),
            _buildDivider(),
            _buildItem(
              label: 'Terms & Conditions',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const TermsConditionsPage()),
              ),
            ),
            _buildDivider(),
            _buildItem(
              label: 'Sign Out',
              onTap: () async {
                onBeforeSignOut?.call();
                await AuthService.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(
                      context, '/type-selection');
                }
              },
            ),
            _buildDivider(),
          ],
        ),
      ),
    );
  }

  Widget _buildItem({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1A1A1A),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF1A1A1A),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 24,
      endIndent: 24,
      color: Color(0xFFEEEEEE),
    );
  }
}
