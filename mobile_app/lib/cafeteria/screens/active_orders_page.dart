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

  // Groups a flat list of docs by orderId (falls back to doc.id for
  // old orders created before orderId was introduced)
  Map<String, List<DocumentSnapshot>> _groupByOrder(
      List<DocumentSnapshot> docs) {
    final grouped = <String, List<DocumentSnapshot>>{};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final key =
          (data['orderId'] as String?)?.isNotEmpty == true
              ? data['orderId'] as String
              : doc.id;
      grouped.putIfAbsent(key, () => []).add(doc);
    }
    return grouped;
  }

  Future<void> _markDelivered(
      String orderId, List<DocumentSnapshot> items) async {
    if (_delivering.contains(orderId)) return;

    if (_stripeAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Connect your bank account in Settings → Bank Account first.'),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _delivering.add(orderId));

    try {
      // Total = sum of price × qty for all items in this order
      double total = 0;
      for (final doc in items) {
        final data = doc.data() as Map<String, dynamic>;
        final price = (data['price'] as num).toDouble();
        final qty = (data['quantity'] as num).toInt();
        total += price * qty;
      }
      final amountCents = (total * 100).toInt();

      // Single transfer for the whole order
      final response = await http.post(
        Uri.parse('$_backendUrl/transfer-to-cafeteria'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amountCents': amountCents,
          'cafeteriaAccountId': _stripeAccountId,
          'selectionId': orderId,
        }),
      );

      if (response.statusCode != 200) {
        throw jsonDecode(response.body)['error'] ?? 'Transfer failed';
      }

      // Mark all items in the order as delivered
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      for (final doc in items) {
        batch.update(doc.reference, {
          'status': 'delivered',
          'isDelivered': true,
          'deliveryDate': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Order delivered! \$${total.toStringAsFixed(2)} sent to your account.'),
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
      if (mounted) setState(() => _delivering.remove(orderId));
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
            if (_stripeAccountId == null) _buildNoBankBanner(),
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
                                color: Color(0xFF9B9B9B)),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'New orders will appear here.',
                            style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF9B9B9B)),
                          ),
                        ],
                      ),
                    );
                  }

                  final grouped =
                      _groupByOrder(snapshot.data!.docs);
                  final orderGroups = grouped.entries.toList();

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        20, 12, 20, 24),
                    itemCount: orderGroups.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final entry = orderGroups[index];
                      return _buildOrderCard(
                          entry.key, entry.value);
                    },
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

  Widget _buildOrderCard(
      String orderId, List<DocumentSnapshot> items) {
    final firstData =
        items.first.data() as Map<String, dynamic>;
    final childName =
        firstData['childName'] as String? ?? 'Student';
    final isDelivering = _delivering.contains(orderId);

    double total = 0;
    for (final doc in items) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['price'] as num).toDouble() *
          (data['quantity'] as num).toInt();
    }

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
            // Child name header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _pink.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_outline,
                      color: _pink, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    childName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
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
            const SizedBox(height: 12),
            const Divider(
                height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 10),
            // Meal items list
            ...items.map((doc) {
              final data =
                  doc.data() as Map<String, dynamic>;
              final mealName =
                  data['mealName'] as String? ?? 'Meal';
              final qty =
                  (data['quantity'] as num?)?.toInt() ?? 1;
              final price =
                  (data['price'] as num?)?.toDouble() ?? 0.0;
              return Padding(
                padding:
                    const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.restaurant,
                        size: 16,
                        color: Color(0xFF9B9B9B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mealName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    Text(
                      '× $qty',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9B9B9B)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '\$${(price * qty).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
            const Divider(
                height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 14),
            // Deliver button
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
                        onPressed: () => _markDelivered(
                            orderId, items),
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
