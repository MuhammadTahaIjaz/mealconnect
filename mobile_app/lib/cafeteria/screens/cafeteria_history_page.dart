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

  // null = show all within 30 days; set = filter to that date
  DateTime? _filterDate;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _pink,
            onPrimary: Colors.white,
            onSurface: Color(0xFF1A1A1A),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() =>
          _filterDate = DateTime(picked.year, picked.month, picked.day));
    }
  }

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
                    .where('cafeteriaId', isEqualTo: uid)
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
                    final d =
                        doc.data() as Map<String, dynamic>;
                    if (d['isDelivered'] != true) return false;
                    // Date filter
                    if (_filterDate != null) {
                      final deliveryTs =
                          d['deliveryDate'] as Timestamp?;
                      if (deliveryTs == null) return false;
                      final dd = deliveryTs.toDate();
                      return _isSameDay(_filterDate!,
                          DateTime(dd.year, dd.month, dd.day));
                    }
                    // Default: last 30 days
                    final ts = d['selectionDate'] as Timestamp?;
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
    const mo = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(
        children: [
          const Text(
            'HISTORY',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Last 30 days  •  Delivered orders',
            style: TextStyle(fontSize: 12, color: Color(0xFF9B9B9B)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _filterDate != null
                        ? _pink.withValues(alpha: 0.10)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _filterDate != null
                          ? _pink
                          : const Color(0xFFEEEEEE),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 14,
                          color: _filterDate != null
                              ? _pink
                              : const Color(0xFF9B9B9B)),
                      const SizedBox(width: 6),
                      Text(
                        _filterDate != null
                            ? '${mo[_filterDate!.month]} ${_filterDate!.day}, ${_filterDate!.year}'
                            : 'Filter by date',
                        style: TextStyle(
                          fontSize: 13,
                          color: _filterDate != null
                              ? _pink
                              : const Color(0xFF9B9B9B),
                          fontWeight: _filterDate != null
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_filterDate != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _filterDate = null),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.close,
                        size: 14, color: Color(0xFF9B9B9B)),
                  ),
                ),
              ],
            ],
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
    // Total earned = sum of all individual items
    double totalEarned = 0;
    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      totalEarned += (d['price'] as num).toDouble() *
          (d['quantity'] as num).toInt();
    }

    // Level 1: group by date
    final byDate =
        <String, List<QueryDocumentSnapshot>>{};
    for (final doc in docs) {
      final ts = ((doc.data() as Map<String, dynamic>)[
              'selectionDate'] as Timestamp)
          .toDate();
      byDate
          .putIfAbsent(_dateLabel(ts), () => [])
          .add(doc);
    }

    // Count distinct orders across all dates
    final totalOrders = _groupByOrderId(docs).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        _buildSummaryCard(totalEarned, totalOrders),
        const SizedBox(height: 8),
        ...byDate.entries.expand((dateEntry) {
          final byOrder = _groupByOrderId(dateEntry.value);
          return [
            Padding(
              padding:
                  const EdgeInsets.only(top: 16, bottom: 8),
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
            ...byOrder.entries
                .map((e) => _buildOrderCard(e.value)),
          ];
        }),
      ],
    );
  }

  Widget _buildSummaryCard(double total, int orderCount) {
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
                      fontSize: 12, color: Colors.white70),
                ),
                Text(
                  'Rs. ${total.toStringAsFixed(2)}',
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
                '$orderCount',
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

  Widget _buildOrderCard(List<QueryDocumentSnapshot> items) {
    final first = items.first.data() as Map<String, dynamic>;
    final childName = first['childName'] as String? ?? '';
    final ts = first['selectionDate'] as Timestamp?;
    final timeStr =
        ts != null ? _timeStr(ts.toDate()) : '';

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
          // Header: child + time
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
                  childName.isNotEmpty
                      ? childName
                      : 'Student',
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
                    'Rs. ${(price * qty).toStringAsFixed(2)}',
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
          // Total + delivered badge
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total  Rs. ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF43A047),
                ),
              ),
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
                        size: 10, color: Color(0xFF43A047)),
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
