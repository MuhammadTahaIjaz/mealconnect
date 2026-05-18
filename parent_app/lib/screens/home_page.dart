import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const _pink = Color(0xFFFF3366);
  static const _orange = Color(0xFFFF8C00);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('parents')
              .doc(uid)
              .snapshots(),
          builder: (context, parentSnap) {
            final raw = parentSnap.hasData && parentSnap.data!.exists
                ? (parentSnap.data!.data()
                    as Map<String, dynamic>)['walletBalance']
                : null;
            final balance = (raw as num?)?.toDouble() ?? 0.0;

            return Column(
              children: [
                const SizedBox(height: 28),
                _buildWalletHeader(balance),
                const SizedBox(height: 24),
                Expanded(child: _buildChildrenList(context, uid, balance)),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Wallet balance header ─────────────────────────────────────────────────

  Widget _buildWalletHeader(double balance) {
    return Column(
      children: [
        Text(
          '\$${balance.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Total Wallet balance',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF9B9B9B),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ── Children list ─────────────────────────────────────────────────────────

  Widget _buildChildrenList(
      BuildContext context, String uid, double balance) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('children')
          .where('parentId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_pink),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildChildCard(data, balance),
              );
            }),
            _buildAddChildButton(context),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  // ── Child card ────────────────────────────────────────────────────────────

  Widget _buildChildCard(Map<String, dynamic> data, double balance) {
    final name = (data['name'] as String?) ?? 'Child';
    final school = (data['schoolName'] as String?) ?? '';
    final schoolId = (data['classRollNo'] as String?) ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_pink, _orange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Middle info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                if (school.isNotEmpty)
                  Text(
                    school,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF9B9B9B)),
                  ),
                if (schoolId.isNotEmpty)
                  Text(
                    schoolId,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF9B9B9B)),
                  ),
                const SizedBox(height: 2),
                _infoRow('Type:', 'Wallet Balance'),
                _infoRow('Duration:', 'Weekly'),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Right side: Edit + wallet balance
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Edit',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _orange,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '\$${balance.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const Text(
                'Wallet balance',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFF9B9B9B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Color(0xFF9B9B9B)),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  // ── Add child button ──────────────────────────────────────────────────────

  Widget _buildAddChildButton(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, '/parent-add-child'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFF3366).withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_pink, _orange],
                ),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Add Child',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
