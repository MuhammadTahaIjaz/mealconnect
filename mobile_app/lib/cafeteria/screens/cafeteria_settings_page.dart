import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'cafeteria_profile_page.dart';
import 'cafeteria_privacy_policy_page.dart';
import 'cafeteria_terms_conditions_page.dart';

class CafeteriaSettingsPage extends StatelessWidget {
  const CafeteriaSettingsPage({super.key});

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
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 32),
            _buildItem(
              label: 'Profile',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CafeteriaProfilePage()),
              ),
            ),
            _buildDivider(),
            _buildItem(
              label: 'Privacy Policy',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const CafeteriaPrivacyPolicyPage()),
              ),
            ),
            _buildDivider(),
            _buildItem(
              label: 'Terms & Conditions',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        const CafeteriaTermsConditionsPage()),
              ),
            ),
            _buildDivider(),
            _buildItem(
              label: 'Sign Out',
              onTap: () async {
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
        padding: const EdgeInsets.symmetric(
            horizontal: 24, vertical: 18),
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
            const Icon(Icons.chevron_right,
                color: Color(0xFF1A1A1A), size: 22),
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
