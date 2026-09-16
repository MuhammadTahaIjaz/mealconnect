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
  String _statusFilter = 'all'; // 'all' | 'delivered' | 'expired'

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

  // status: 'delivered' | 'expired' | 'pending'
  String _orderStatus(Map<String, dynamic> d) {
    if (d['isDelivered'] == true) return 'delivered';
    final deliveryTs = d['deliveryDate'] as Timestamp?;
    if (deliveryTs != null) {
      final today = DateTime.now();
      final todayMidnight = DateTime(today.year, today.month, today.day);
      final deliveryDay = deliveryTs.toDate();
      final deliveryMidnight =
          DateTime(deliveryDay.year, deliveryDay.month, deliveryDay.day);
      if (deliveryMidnight.isBefore(todayMidnight)) return 'expired';
    }
    return 'pending';
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
                    final status = _orderStatus(d);
                    if (status == 'pending') return false;
                    if (_statusFilter != 'all' &&
                        status != _statusFilter) {
                      return false;
                    }
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
            'Last 30 days',
            style: TextStyle(fontSize: 12, color: Color(0xFF9B9B9B)),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
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
              if (_filterDate != null)
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
              _buildStatusFilter(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    const labels = {
      'all': 'All',
      'delivered': 'Delivered',
      'expired': 'Expired',
    };
    final active = _statusFilter != 'all';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: active ? _pink.withValues(alpha: 0.10) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? _pink : const Color(0xFFEEEEEE),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusFilter,
          icon: Icon(Icons.keyboard_arrow_down,
              size: 16, color: active ? _pink : const Color(0xFF9B9B9B)),
          style: TextStyle(
            fontSize: 13,
            color: active ? _pink : const Color(0xFF9B9B9B),
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
          items: labels.entries
              .map((e) =>
                  DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _statusFilter = v);
          },
        ),
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
            'No order history in the last 30 days.',
            style: TextStyle(
                fontSize: 14, color: Color(0xFF9B9B9B)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<QueryDocumentSnapshot> docs) {
    // Total earned = sum of delivered items only (expired orders were refunded, not earned)
    double totalEarned = 0;
    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      if (_orderStatus(d) != 'delivered') continue;
      totalEarned += (d['price'] as num).toDouble() *
          (d['quantity'] as num).toInt();
    }

    // Group by date only — each meal item gets its own card
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

    final totalItems = docs.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        _buildSummaryCard(totalEarned, totalItems),
        const SizedBox(height: 8),
        ...byDate.entries.expand((dateEntry) {
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
            ...dateEntry.value.map((doc) => _buildOrderCard([doc])),
          ];
        }),
      ],
    );
  }

  Widget _buildSummaryCard(double total, int itemCount) {
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
                '$itemCount',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Text(
                'items',
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
    final status = _orderStatus(first);
    final deliveryTs = first['deliveryDate'] as Timestamp?;
    final deliveryStr = deliveryTs == null
        ? ''
        : status == 'delivered'
            ? _timeStr(deliveryTs.toDate())
            : _dateOnlyStr(deliveryTs.toDate());

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Ordered: $timeStr',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9B9B9B)),
                  ),
                  if (deliveryStr.isNotEmpty)
                    Text(
                      status == 'delivered'
                          ? 'Delivered: $deliveryStr'
                          : 'Expired: $deliveryStr',
                      style: TextStyle(
                          fontSize: 11,
                          color: status == 'delivered'
                              ? const Color(0xFF43A047)
                              : const Color(0xFFE53935)),
                    ),
                ],
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
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: status == 'delivered'
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        status == 'delivered'
                            ? Icons.check_circle
                            : Icons.cancel_outlined,
                        size: 10,
                        color: status == 'delivered'
                            ? const Color(0xFF43A047)
                            : const Color(0xFFE53935)),
                    const SizedBox(width: 3),
                    Text(
                      status == 'delivered' ? 'Delivered' : 'Expired',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: status == 'delivered'
                            ? const Color(0xFF43A047)
                            : const Color(0xFFE53935),
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
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final amPm = dt.hour < 12 ? 'AM' : 'PM';
    final time = '$h:${dt.minute.toString().padLeft(2, '0')} $amPm';
    return '$date  •  $time';
  }

  String _dateOnlyStr(DateTime dt) {
    const mo = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${mo[dt.month - 1]}';
  }
}
