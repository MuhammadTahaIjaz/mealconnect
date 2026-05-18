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
        child: Column(
          children: [
            const SizedBox(height: 24),
            _buildWalletBalance(uid),
            const SizedBox(height: 24),
            Expanded(child: _buildChildrenList(uid)),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletBalance(String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('parents')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        double balance = 0;
        if (snapshot.hasData && snapshot.data!.exists) {
          balance = (snapshot.data!.data()
                  as Map<String, dynamic>)['walletBalance'] ??
              0;
        }
        return Column(
          children: [
            Text(
              '\$${balance.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 42,
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
      },
    );
  }

  Widget _buildChildrenList(String uid) {
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

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.child_care,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text(
                  'No children added yet.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF9B9B9B),
                  ),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _buildChildCard(data);
          },
        );
      },
    );
  }

  Widget _buildChildCard(Map<String, dynamic> data) {
    final name = data['name'] ?? 'Child';
    final schoolName = data['schoolName'] ?? '';
    final schoolId = data['classRollNo'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
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
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
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
                if (schoolName.isNotEmpty)
                  Text(
                    schoolName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9B9B9B),
                    ),
                  ),
                if (schoolId.isNotEmpty)
                  Text(
                    schoolId,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9B9B9B),
                    ),
                  ),
              ],
            ),
          ),
          const Text(
            'Edit',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _orange,
            ),
          ),
        ],
      ),
    );
  }
}
