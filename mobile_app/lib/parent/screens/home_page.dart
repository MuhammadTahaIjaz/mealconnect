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
                Expanded(child: _buildChildrenList(context, uid)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWalletHeader(double balance) {
    return Column(
      children: [
        Text(
          'Rs. ${balance.toStringAsFixed(2)}',
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

  Widget _buildChildrenList(BuildContext context, String uid) {
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

        int statusRank(String s) =>
            s == 'approved' ? 0 : s == 'pending' ? 1 : 2;

        final docs = (snapshot.data?.docs ?? [])
          ..sort((a, b) {
            final sa = (a.data() as Map<String, dynamic>)['verificationStatus']
                    as String? ??
                'pending';
            final sb = (b.data() as Map<String, dynamic>)['verificationStatus']
                    as String? ??
                'pending';
            return statusRank(sa).compareTo(statusRank(sb));
          });

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Padding(
                key: ValueKey(doc.id),
                padding: const EdgeInsets.only(bottom: 16),
                child: _ChildCard(childId: doc.id, data: data),
              );
            }),
            _buildAddChildButton(context),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildAddChildButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/parent-add-child'),
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

// ── Child Card ────────────────────────────────────────────────────────────────

class _ChildCard extends StatefulWidget {
  final String childId;
  final Map<String, dynamic> data;

  const _ChildCard({
    required this.childId,
    required this.data,
  });

  @override
  State<_ChildCard> createState() => _ChildCardState();
}

class _ChildCardState extends State<_ChildCard> {
  static const _pink = Color(0xFFFF3366);
  static const _orange = Color(0xFFFF8C00);

  bool _isDeleting = false;

  Future<void> _handleDelete() async {
    final db = FirebaseFirestore.instance;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final name = (widget.data['name'] as String?) ?? 'Child';

    // Show spinner immediately — visible while the query runs
    setState(() => _isDeleting = true);

    try {
      final pendingSnap = await db
          .collection('mealSelections')
          .where('childId', isEqualTo: widget.childId)
          .where('isDelivered', isEqualTo: false)
          .get();

      final pendingCount = pendingSnap.docs.length;
      final refundTotal = pendingSnap.docs.fold<double>(0, (acc, doc) {
        final d = doc.data();
        return acc +
            (d['price'] as num).toDouble() *
                (d['quantity'] as num).toInt();
      });

      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Child',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to remove $name? This cannot be undone.',
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF9B9B9B)),
              ),
              if (pendingCount > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$pendingCount pending meal order${pendingCount == 1 ? '' : 's'} will be cancelled and Rs. ${refundTotal.toStringAsFixed(2)} will be refunded to your wallet.',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF2E7D32)),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF9B9B9B))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(
                      color: Color(0xFFE53935),
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        if (mounted) setState(() => _isDeleting = false);
        return;
      }

      final batch = db.batch();
      for (final doc in pendingSnap.docs) {
        batch.delete(doc.reference);
      }
      if (refundTotal > 0) {
        batch.update(db.collection('parents').doc(uid), {
          'walletBalance': FieldValue.increment(refundTotal),
        });
      }
      batch.delete(db.collection('children').doc(widget.childId));
      await batch.commit();
    } catch (_) {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.data['name'] as String?) ?? 'Child';
    final rollNumber = (widget.data['rollNumber'] as String?)
        ?? (widget.data['classRollNo'] as String?) ?? '';
    final verificationStatus =
        (widget.data['verificationStatus'] as String?) ?? 'pending';
    final mealConnectId = (widget.data['mealConnectId'] as String?) ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isApproved = verificationStatus == 'approved';

    return GestureDetector(
      onTap: isApproved
          ? () => Navigator.pushNamed(
                context,
                '/parent-cafeteria',
                arguments: {
                  'childId': widget.childId,
                  'name': name,
                  'schoolId': (widget.data['schoolId'] as String?) ?? '',
                  'mealConnectId': mealConnectId,
                },
              )
          : null,
      child: Container(
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      _buildVerificationBadge(verificationStatus),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (rollNumber.isNotEmpty)
                    Text(
                      'Roll No: $rollNumber',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF9B9B9B)),
                    ),
                  if (mealConnectId.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_pink, _orange],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'ID: $mealConnectId',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  _infoRow('Type:', 'Wallet Balance'),
                  _infoRow('Duration:', 'Weekly'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _editPill(context),
                      const SizedBox(width: 8),
                      _deletePill(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editPill(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/parent-edit-child',
        arguments: {'childId': widget.childId, 'data': widget.data},
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _orange.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _orange.withValues(alpha: 0.35)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_outlined, size: 13, color: _orange),
            SizedBox(width: 4),
            Text(
              'Edit',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deletePill() {
    return GestureDetector(
      onTap: _isDeleting ? null : _handleDelete,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.35)),
        ),
        child: _isDeleting
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Color(0xFFE53935),
                ),
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline, size: 13, color: Color(0xFFE53935)),
                  SizedBox(width: 4),
                  Text(
                    'Delete',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE53935),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildVerificationBadge(String status) {
    switch (status) {
      case 'approved':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check_circle, size: 12, color: Color(0xFF43A047)),
              SizedBox(width: 3),
              Text(
                'Verified',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF43A047)),
              ),
            ],
          ),
        );
      case 'rejected':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.cancel, size: 12, color: Color(0xFFE53935)),
              SizedBox(width: 3),
              Text(
                'Rejected',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE53935)),
              ),
            ],
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.hourglass_empty, size: 12, color: Color(0xFFF5A623)),
              SizedBox(width: 3),
              Text(
                'Pending',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF5A623)),
              ),
            ],
          ),
        );
    }
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
}
