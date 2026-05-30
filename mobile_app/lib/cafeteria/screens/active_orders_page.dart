import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class ActiveOrdersPage extends StatefulWidget {
  const ActiveOrdersPage({super.key});

  @override
  State<ActiveOrdersPage> createState() => _ActiveOrdersPageState();
}

class _ActiveOrdersPageState extends State<ActiveOrdersPage> {
  static const _pink = Color(0xFFFF3366);
  static const _orange = Color(0xFFFF8C00);
  static const _backendUrl = 'http://72.61.254.215:3000';

  String? _stripeAccountId;
  final Set<String> _delivering = {};

  @override
  void initState() {
    super.initState();
    _loadStripeAccount();
  }

  Future<void> _loadStripeAccount() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('cafeterias')
        .doc(uid)
        .get();
    if (mounted) {
      setState(() {
        _stripeAccountId =
            doc.data()?['stripeAccountId'] as String?;
      });
    }
  }

  Future<void> _markDelivered(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final selectionId = doc.id;

    if (_delivering.contains(selectionId)) return;

    if (_stripeAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Connect your bank account in Settings → Bank Account first.'),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
      return;
    }

    setState(() => _delivering.add(selectionId));

    try {
      final price = (data['price'] as num).toDouble();
      final qty = (data['quantity'] as num).toInt();
      final amountCents = (price * qty * 100).toInt();

      // Transfer payment to cafeteria
      final response = await http.post(
        Uri.parse('$_backendUrl/transfer-to-cafeteria'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amountCents': amountCents,
          'cafeteriaAccountId': _stripeAccountId,
          'selectionId': selectionId,
        }),
      );

      if (response.statusCode != 200) {
        throw jsonDecode(response.body)['error'] ?? 'Transfer failed';
      }

      // Mark as delivered in Firestore
      await FirebaseFirestore.instance
          .collection('mealSelections')
          .doc(selectionId)
          .update({
        'status': 'delivered',
        'isDelivered': true,
        'deliveryDate': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Delivered! \$${(amountCents / 100).toStringAsFixed(2)} sent to your account.'),
            backgroundColor: const Color(0xFF43A047),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _delivering.remove(selectionId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            if (_stripeAccountId == null)
              _buildNoBankBanner(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('mealSelections')
                    .where('cafeteriaId', isEqualTo: uid)
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_pink),
                      ),
                    );
                  }

                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 64,
                              color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text(
                            'No pending orders.',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF9B9B9B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'New orders will appear here.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9B9B9B),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final docs = snapshot.data!.docs;
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        20, 12, 20, 24),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildOrderCard(docs[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        children: [
          Text(
            'ACTIVE ORDERS',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              color: Color(0xFF1A1A1A),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tap deliver when meal is handed to the student',
            style:
                TextStyle(fontSize: 12, color: Color(0xFF9B9B9B)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoBankBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFFF5A623).withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.account_balance_outlined,
              size: 18, color: Color(0xFF8B6900)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Go to Settings → Bank Account to receive payments.',
              style: TextStyle(
                  fontSize: 12, color: Color(0xFF8B6900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final mealName = data['mealName'] as String? ?? 'Meal';
    final childName = data['childName'] as String? ?? '';
    final qty = (data['quantity'] as num?)?.toInt() ?? 1;
    final price = (data['price'] as num?)?.toDouble() ?? 0.0;
    final total = price * qty;
    final isDelivering = _delivering.contains(doc.id);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _pink.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.restaurant,
                      color: _pink, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        mealName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        childName.isNotEmpty
                            ? 'For: $childName'
                            : '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9B9B9B),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _pink,
                  ),
                ),
              ],
            ),
            if (qty > 1) ...[
              const SizedBox(height: 8),
              Text(
                'Qty: $qty  ×  \$${price.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF9B9B9B)),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: isDelivering
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(
                                  _pink),
                        ),
                      ),
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [_pink, _orange]),
                        borderRadius:
                            BorderRadius.circular(22),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _markDelivered(doc),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      22)),
                        ),
                        icon: const Icon(
                            Icons.check_circle_outline,
                            color: Colors.white,
                            size: 18),
                        label: const Text(
                          'MARK AS DELIVERED',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
