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

  DateTime? _filterDate;
  String _statusFilter = 'all'; // 'all' | 'delivered' | 'pending' | 'expired'

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
                    final d = doc.data() as Map<String, dynamic>;
                    final ts = d['selectionDate'] as Timestamp?;
                    if (ts == null) return false;
                    if (_statusFilter != 'all' &&
                        _orderStatus(d) != _statusFilter) {
                      return false;
                    }
                    if (_filterDate != null) {
                      final dd = ts.toDate();
                      return _isSameDay(
                          _filterDate!, DateTime(dd.year, dd.month, dd.day));
                    }
                    return ts.toDate().isAfter(cutoff);
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
      'pending': 'Pending',
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
    const mo = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final msg = _filterDate != null
        ? 'No orders on ${mo[_filterDate!.month]} ${_filterDate!.day}.'
        : 'No orders in the last 30 days.';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            msg,
            style: const TextStyle(fontSize: 14, color: Color(0xFF9B9B9B)),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<QueryDocumentSnapshot> docs) {
    double totalSpent = 0;
    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      totalSpent += (d['price'] as num).toDouble() *
          (d['quantity'] as num).toInt();
    }
    final totalItems = docs.length;

    // Group by date only — each meal item gets its own card
    final byDate = <String, List<QueryDocumentSnapshot>>{};
    for (final doc in docs) {
      final ts = ((doc.data() as Map<String, dynamic>)[
              'selectionDate'] as Timestamp)
          .toDate();
      byDate.putIfAbsent(_dateLabel(ts), () => []).add(doc);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        _buildSummaryCard(totalSpent, totalItems),
        const SizedBox(height: 8),
        ...byDate.entries.expand((dateEntry) {
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
        gradient: const LinearGradient(colors: [_pink, Color(0xFFFF8C00)]),
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
          const Icon(Icons.account_balance_wallet_outlined,
              color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Spent',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
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
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static final Map<String, Future<String>> _idCache = {};

  static Future<String> _fetchMealConnectId(String childId) =>
      _idCache.putIfAbsent(
        childId,
        () => FirebaseFirestore.instance
            .collection('children')
            .doc(childId)
            .get()
            .then((s) => (s.data()?['mealConnectId'] as String?) ?? ''),
      );

  Widget _mealConnectIdLabel(String childId) {
    if (childId.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<String>(
      future: _fetchMealConnectId(childId),
      builder: (_, snap) {
        final id = snap.data ?? '';
        if (id.isEmpty) return const SizedBox.shrink();
        return Text('ID: $id',
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF9B9B9B)));
      },
    );
  }

  Widget _buildOrderCard(List<QueryDocumentSnapshot> items) {
    final first = items.first.data() as Map<String, dynamic>;
    final childName = first['childName'] as String? ?? '';
    final childId = first['childId'] as String? ?? '';
    final ts = first['selectionDate'] as Timestamp?;
    final orderedStr =
        ts != null ? _timeOnly(ts.toDate()) : '';
    final status = _orderStatus(first);

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      childName.isNotEmpty ? childName : 'Student',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    _mealConnectIdLabel(childId),
                  ],
                ),
              ),
              if (orderedStr.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Ordered',
                        style: TextStyle(
                            fontSize: 10, color: Color(0xFF9B9B9B))),
                    Text(orderedStr,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9B9B9B))),
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
            final isDelivered = d['isDelivered'] == true;
            final deliveryTs = d['deliveryDate'] as Timestamp?;
            final deliveryStr = deliveryTs == null
                ? ''
                : isDelivered
                    ? _deliveryDateStr(deliveryTs.toDate())
                    : _dateOnlyStr(deliveryTs.toDate());
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.restaurant,
                      size: 14, color: Color(0xFF9B9B9B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mealName,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1A1A1A)),
                        ),
                        if (deliveryStr.isNotEmpty)
                          Text(
                            isDelivered
                                ? 'Delivered: $deliveryStr'
                                : 'Scheduled for: $deliveryStr',
                            style: TextStyle(
                                fontSize: 11,
                                color: isDelivered
                                    ? const Color(0xFF43A047)
                                    : const Color(0xFFF5A623)),
                          ),
                      ],
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
          // Total + status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total  Rs. ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              _statusBadge(status),
            ],
          ),
        ],
      ),
    );
  }

  // status: 'delivered' | 'pending' | 'expired'
  String _orderStatus(Map<String, dynamic> first) {
    if (first['isDelivered'] == true) return 'delivered';
    final deliveryTs = first['deliveryDate'] as Timestamp?;
    if (deliveryTs != null) {
      final deliveryDay = deliveryTs.toDate();
      final today = DateTime.now();
      final todayMidnight =
          DateTime(today.year, today.month, today.day);
      final deliveryMidnight = DateTime(
          deliveryDay.year, deliveryDay.month, deliveryDay.day);
      if (deliveryMidnight.isBefore(todayMidnight)) {
        return 'expired';
      }
    }
    return 'pending';
  }

  Widget _statusBadge(String status) {
    final Color bg;
    final Color fg;
    final IconData icon;
    final String label;
    switch (status) {
      case 'delivered':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF43A047);
        icon = Icons.check_circle;
        label = 'Delivered';
        break;
      case 'expired':
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFE53935);
        icon = Icons.cancel_outlined;
        label = 'Expired';
        break;
      default:
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF5A623);
        icon = Icons.hourglass_empty;
        label = 'Pending';
    }
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: fg)),
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

  String _timeOnly(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final amPm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:${dt.minute.toString().padLeft(2, '0')} $amPm';
  }

  String _deliveryDateStr(DateTime dt) {
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final amPm = dt.hour < 12 ? 'AM' : 'PM';
    final time = '$h:${dt.minute.toString().padLeft(2, '0')} $amPm';
    return '${days[dt.weekday]}, ${dt.day} ${mo[dt.month]}  $time';
  }

  String _dateOnlyStr(DateTime dt) {
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[dt.weekday]}, ${dt.day} ${mo[dt.month]}';
  }
}
