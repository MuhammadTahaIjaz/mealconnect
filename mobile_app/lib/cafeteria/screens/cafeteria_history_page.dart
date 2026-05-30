import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CafeteriaHistoryPage extends StatefulWidget {
  const CafeteriaHistoryPage({super.key});

  @override
  State<CafeteriaHistoryPage> createState() =>
      _CafeteriaHistoryPageState();
}

class _CafeteriaHistoryPageState
    extends State<CafeteriaHistoryPage> {
  static const _pink = Color(0xFFFF3366);
  static const _orange = Color(0xFFFF8C00);

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
                    .where('cafeteriaId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(
                                _pink),
                      ),
                    );
                  }

                  // Filter: last 30 days + delivered only, newest first
                  final docs =
                      (snapshot.data?.docs ?? []).where((doc) {
                    final d = doc.data()
                        as Map<String, dynamic>;
                    final ts =
                        d['selectionDate'] as Timestamp?;
                    return d['isDelivered'] == true &&
                        ts != null &&
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

                  if (docs.isEmpty) {
                    return _buildEmpty();
                  }

                  return _buildContent(docs);
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
            'Last 30 days  •  Delivered orders',
            style: TextStyle(
                fontSize: 12, color: Color(0xFF9B9B9B)),
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
            'No deliveries in the last 30 days.',
            style: TextStyle(
                fontSize: 14, color: Color(0xFF9B9B9B)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<QueryDocumentSnapshot> docs) {
    // Compute totals for summary card
    double totalEarned = 0;
    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final price = (d['price'] as num?)?.toDouble() ?? 0.0;
      final qty = (d['quantity'] as int?) ?? 1;
      totalEarned += price * qty;
    }

    // Group by date label
    final grouped =
        <String, List<QueryDocumentSnapshot>>{};
    for (final doc in docs) {
      final ts = ((doc.data() as Map<String, dynamic>)[
              'selectionDate'] as Timestamp)
          .toDate();
      grouped
          .putIfAbsent(_dateLabel(ts), () => [])
          .add(doc);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        // ── Earnings summary card ──────────────────────
        _buildSummaryCard(totalEarned, docs.length),
        const SizedBox(height: 8),

        // ── Grouped order list ─────────────────────────
        ...grouped.entries.expand((entry) => [
              Padding(
                padding: const EdgeInsets.only(
                    top: 16, bottom: 8),
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9B9B9B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              ...entry.value.map((doc) => _buildCard(
                  doc.data() as Map<String, dynamic>)),
            ]),
      ],
    );
  }

  Widget _buildSummaryCard(double total, int count) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(colors: [_pink, _orange]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _pink.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined,
              color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Earned',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70),
                ),
                Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Text(
                'orders',
                style: TextStyle(
                    fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> d) {
    final mealName = (d['mealName'] as String?) ?? 'Meal';
    final price = (d['price'] as num?)?.toDouble() ?? 0.0;
    final qty = (d['quantity'] as int?) ?? 1;
    final childName = (d['childName'] as String?) ?? '';
    final childId = (d['childId'] as String?) ?? '';
    final ts = d['selectionDate'] as Timestamp?;
    final timeStr =
        ts != null ? _timeStr(ts.toDate()) : '';

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.fastfood_outlined,
                size: 20, color: Color(0xFFCCCCCC)),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mealName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  childName.isNotEmpty
                      ? childName
                      : 'ID: $childId',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9B9B9B)),
                ),
                Text(
                  '× $qty  •  $timeStr',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9B9B9B)),
                ),
              ],
            ),
          ),
          // Earned amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${(price * qty).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF43A047),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle,
                        size: 10,
                        color: Color(0xFF43A047)),
                    SizedBox(width: 3),
                    Text(
                      'Delivered',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF43A047),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today =
        DateTime(now.year, now.month, now.day);
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
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
