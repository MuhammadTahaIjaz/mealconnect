import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const _pink = Color(0xFFFF3366);

  @override
  void initState() {
    super.initState();
    _cleanupOldOrders();
  }

  Future<void> _cleanupOldOrders() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 30)),
      );
      final snap = await FirebaseFirestore.instance
          .collection('mealSelections')
          .where('parentId', isEqualTo: uid)
          .get();
      final old = snap.docs.where((doc) {
        final ts = doc.data()['selectionDate'] as Timestamp?;
        return ts != null && ts.compareTo(cutoff) < 0;
      }).toList();
      if (old.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in old) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
  }

  // Group a flat list by orderId, falling back to doc.id for old records
  Map<String, List<QueryDocumentSnapshot>> _groupByOrderId(
      List<QueryDocumentSnapshot> docs) {
    final grouped = <String, List<QueryDocumentSnapshot>>{};
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

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final cutoff =
        DateTime.now().subtract(const Duration(days: 30));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('mealSelections')
                    .where('parentId', isEqualTo: uid)
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

                  final docs =
                      (snapshot.data?.docs ?? []).where((doc) {
                    final ts = (doc.data()
                            as Map<String, dynamic>)[
                        'selectionDate'] as Timestamp?;
                    return ts != null &&
                        ts.toDate().isAfter(cutoff);
                  }).toList()
                        ..sort((a, b) {
                          final aMs =
                              ((a.data() as Map)['selectionDate']
                                      as Timestamp)
                                  .millisecondsSinceEpoch;
                          final bMs =
                              ((b.data() as Map)['selectionDate']
                                      as Timestamp)
                                  .millisecondsSinceEpoch;
                          return bMs.compareTo(aMs);
                        });

                  if (docs.isEmpty) return _buildEmpty();
                  return _buildList(docs);
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
      padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        children: [
          Text(
            'HISTORY',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              color: Color(0xFF1A1A1A),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Last 30 days',
            style:
                TextStyle(fontSize: 12, color: Color(0xFF9B9B9B)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No orders in the last 30 days.',
            style: TextStyle(
                fontSize: 14, color: Color(0xFF9B9B9B)),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<QueryDocumentSnapshot> docs) {
    // Level 1: group by date
    final byDate =
        <String, List<QueryDocumentSnapshot>>{};
    for (final doc in docs) {
      final ts = ((doc.data() as Map<String, dynamic>)[
              'selectionDate'] as Timestamp)
          .toDate();
      byDate.putIfAbsent(_dateLabel(ts), () => []).add(doc);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: byDate.entries.expand((dateEntry) {
        // Level 2: group by orderId within each date
        final byOrder = _groupByOrderId(dateEntry.value);
        return [
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              dateEntry.key,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9B9B9B),
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...byOrder.entries.map(
              (e) => _buildOrderCard(e.value)),
        ];
      }).toList(),
    );
  }

  Widget _buildOrderCard(List<QueryDocumentSnapshot> items) {
    final first = items.first.data() as Map<String, dynamic>;
    final childName = first['childName'] as String? ?? '';
    final ts = first['selectionDate'] as Timestamp?;
    final timeStr =
        ts != null ? _timeStr(ts.toDate()) : '';
    final isDelivered = first['isDelivered'] == true;

    double total = 0;
    for (final doc in items) {
      final d = doc.data() as Map<String, dynamic>;
      total += (d['price'] as num).toDouble() *
          (d['quantity'] as num).toInt();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: child + time
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_outline,
                    size: 20, color: Color(0xFFCCCCCC)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  childName.isNotEmpty ? childName : 'Student',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              Text(
                timeStr,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF9B9B9B)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 8),
          // Meal items
          ...items.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final mealName =
                d['mealName'] as String? ?? 'Meal';
            final qty = (d['quantity'] as num).toInt();
            final price = (d['price'] as num).toDouble();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.restaurant,
                      size: 14, color: Color(0xFF9B9B9B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mealName,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1A1A1A)),
                    ),
                  ),
                  Text(
                    '× $qty',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9B9B9B)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '\$${(price * qty).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 12, color: Color(0xFFF0F0F0)),
          // Total + status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total  \$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              _statusBadge(isDelivered),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(bool delivered) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: delivered
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            delivered
                ? Icons.check_circle
                : Icons.hourglass_empty,
            size: 10,
            color: delivered
                ? const Color(0xFF43A047)
                : const Color(0xFFF5A623),
          ),
          const SizedBox(width: 3),
          Text(
            delivered ? 'Delivered' : 'Pending',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: delivered
                  ? const Color(0xFF43A047)
                  : const Color(0xFFF5A623),
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    const mo = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${mo[dt.month - 1]}';
  }

  String _timeStr(DateTime dt) {
    const mo = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final date = '${dt.day} ${mo[dt.month - 1]}';
    final time = '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
    return '$date  •  $time';
  }
}
