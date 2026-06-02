import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SpendingPage extends StatefulWidget {
  const SpendingPage({super.key});

  @override
  State<SpendingPage> createState() => _SpendingPageState();
}

class _SpendingPageState extends State<SpendingPage> {
  static const _pink = Color(0xFFFF3366);
  static const _orange = Color(0xFFFF8C00);

  // 'today' | 'day' | 'range'
  String _mode = 'today';
  DateTime? _selectedDate;
  DateTime? _startDate;
  DateTime? _endDate;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime get _minDate =>
      _today.subtract(const Duration(days: 30));

  // ── Date pickers ──────────────────────────────────────────────────────────

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? _today,
      firstDate: _minDate,
      lastDate: _today,
      builder: _calendarTheme,
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate =
          DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? _today,
      firstDate: _minDate,
      lastDate: _today,
      builder: _calendarTheme,
    );
    if (picked != null && mounted) {
      final start =
          DateTime(picked.year, picked.month, picked.day);
      setState(() {
        _startDate = start;
        if (_endDate != null &&
            (_endDate!.isBefore(start) ||
                _endDate!.difference(start).inDays > 30)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please select a start date first.'),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }
    final maxEnd =
        _startDate!.add(const Duration(days: 30)).isBefore(_today)
            ? _startDate!.add(const Duration(days: 30))
            : _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
      lastDate: maxEnd,
      builder: _calendarTheme,
    );
    if (picked != null && mounted) {
      setState(() => _endDate =
          DateTime(picked.year, picked.month, picked.day));
    }
  }

  Widget _calendarTheme(BuildContext ctx, Widget? child) =>
      Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _pink,
            onPrimary: Colors.white,
            onSurface: Color(0xFF1A1A1A),
          ),
        ),
        child: child!,
      );

  // ── Filter logic ──────────────────────────────────────────────────────────

  bool _matchesFilter(Map<String, dynamic> data) {
    final ts = data['selectionDate'] as Timestamp?;
    if (ts == null) return false;
    final dt = ts.toDate();
    final d = DateTime(dt.year, dt.month, dt.day);

    switch (_mode) {
      case 'today':
        return d == _today;
      case 'day':
        return _selectedDate != null && d == _selectedDate;
      case 'range':
        if (_startDate == null || _endDate == null) return false;
        return !d.isBefore(_startDate!) && !d.isAfter(_endDate!);
      default:
        return false;
    }
  }

  bool get _filterReady {
    if (_mode == 'today') return true;
    if (_mode == 'day') return _selectedDate != null;
    return _startDate != null && _endDate != null;
  }

  String _orderStatus(Map<String, dynamic> first) {
    if (first['isDelivered'] == true) return 'delivered';
    final deliveryTs = first['deliveryDate'] as Timestamp?;
    if (deliveryTs != null) {
      final d = deliveryTs.toDate();
      final day = DateTime(d.year, d.month, d.day);
      if (day.isBefore(_today)) return 'expired';
    }
    return 'pending';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Map<String, List<QueryDocumentSnapshot>> _groupByOrder(
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

  String _formatDate(DateTime d) {
    const mo = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${mo[d.month]} ${d.day}, ${d.year}';
  }

  String _periodLabel() {
    switch (_mode) {
      case 'today':
        return _formatDate(_today);
      case 'day':
        return _selectedDate != null
            ? _formatDate(_selectedDate!)
            : 'Select a day';
      case 'range':
        if (_startDate != null && _endDate != null) {
          return '${_formatDate(_startDate!)}  —  ${_formatDate(_endDate!)}';
        }
        if (_startDate != null) {
          return '${_formatDate(_startDate!)}  —  ?';
        }
        return 'Select date range';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Color(0xFF1A1A1A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'MY SPENDING',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: Color(0xFF1A1A1A),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('mealSelections')
              .where('parentId', isEqualTo: uid)
              .snapshots(),
          builder: (context, snapshot) {
            final allDocs = snapshot.hasData
                ? snapshot.data!.docs
                    .cast<QueryDocumentSnapshot>()
                : <QueryDocumentSnapshot>[];

            final filtered = _filterReady
                ? allDocs
                    .where((doc) => _matchesFilter(
                        doc.data() as Map<String, dynamic>))
                    .toList()
                : <QueryDocumentSnapshot>[];

            double totalSpent = 0;
            for (final doc in filtered) {
              final d = doc.data() as Map<String, dynamic>;
              totalSpent +=
                  (d['price'] as num).toDouble() *
                      (d['quantity'] as num).toInt();
            }

            final grouped = _groupByOrder(filtered);

            return SingleChildScrollView(
              padding:
                  const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterSection(),
                  const SizedBox(height: 20),
                  _buildSummaryCard(
                      totalSpent, grouped.length),
                  const SizedBox(height: 20),
                  if (!_filterReady)
                    _buildPickPrompt()
                  else if (grouped.isEmpty)
                    _buildEmpty()
                  else ...[
                    Text(
                      '${grouped.length} order${grouped.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9B9B9B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...grouped.entries.map(
                        (e) => _buildOrderCard(e.value)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Filter section ────────────────────────────────────────────────────────

  Widget _buildFilterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _modeChip('today', 'Today'),
            const SizedBox(width: 8),
            _modeChip('day', 'Specific Day'),
            const SizedBox(width: 8),
            _modeChip('range', 'Date Range'),
          ],
        ),
        if (_mode == 'day') ...[
          const SizedBox(height: 12),
          _datePicker(
            label: _selectedDate != null
                ? _formatDate(_selectedDate!)
                : 'Pick a day',
            hasValue: _selectedDate != null,
            onTap: _pickDay,
          ),
        ],
        if (_mode == 'range') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _datePicker(
                  label: _startDate != null
                      ? _formatDate(_startDate!)
                      : 'From',
                  hasValue: _startDate != null,
                  onTap: _pickStartDate,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _datePicker(
                  label: _endDate != null
                      ? _formatDate(_endDate!)
                      : 'To',
                  hasValue: _endDate != null,
                  onTap: _pickEndDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Maximum range: 30 days',
            style: TextStyle(
                fontSize: 11, color: Color(0xFF9B9B9B)),
          ),
        ],
      ],
    );
  }

  Widget _modeChip(String mode, String label) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [_pink, _orange])
              : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? Colors.white
                : const Color(0xFF9B9B9B),
          ),
        ),
      ),
    );
  }

  Widget _datePicker({
    required String label,
    required bool hasValue,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hasValue
              ? _pink.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasValue
                ? _pink.withValues(alpha: 0.40)
                : const Color(0xFFEEEEEE),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 16,
                color: hasValue
                    ? _pink
                    : const Color(0xFF9B9B9B)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: hasValue
                      ? _pink
                      : const Color(0xFF9B9B9B),
                  fontWeight: hasValue
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Summary card ──────────────────────────────────────────────────────────

  Widget _buildSummaryCard(double total, int orders) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(colors: [_pink, _orange]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _pink.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _periodLabel(),
            style: const TextStyle(
                fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            'Rs. ${total.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.shopping_bag_outlined,
                  size: 14, color: Colors.white70),
              const SizedBox(width: 5),
              Text(
                '$orders order${orders == 1 ? '' : 's'} placed',
                style: const TextStyle(
                    fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Empty / Prompt states ─────────────────────────────────────────────────

  Widget _buildPickPrompt() {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.date_range_outlined,
                size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            Text(
              _mode == 'day'
                  ? 'Pick a day to view spending.'
                  : 'Select a start and end date.',
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF9B9B9B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            const Text(
              'No orders found for this period.',
              style: TextStyle(
                  fontSize: 14, color: Color(0xFF9B9B9B)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Order card ────────────────────────────────────────────────────────────

  Widget _buildOrderCard(List<QueryDocumentSnapshot> items) {
    final first = items.first.data() as Map<String, dynamic>;
    final childName = first['childName'] as String? ?? '';
    final childRollNo =
        first['childRollNo'] as String? ?? '';
    final ts = first['selectionDate'] as Timestamp?;
    final orderDate = ts != null ? _formatDate(ts.toDate()) : '';
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
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      childName.isNotEmpty
                          ? childName
                          : 'Student',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    if (childRollNo.isNotEmpty)
                      Text('ID: $childRollNo',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9B9B9B))),
                    Text(orderDate,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9B9B9B))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs. ${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _statusBadge(status),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 8),
          ...items.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final mealName =
                d['mealName'] as String? ?? 'Meal';
            final qty =
                (d['quantity'] as num?)?.toInt() ?? 1;
            final price =
                (d['price'] as num?)?.toDouble() ?? 0.0;
            final dayName =
                d['deliveryDay'] as String? ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.restaurant,
                      size: 13, color: Color(0xFF9B9B9B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      dayName.isNotEmpty
                          ? '$mealName ($dayName)'
                          : mealName,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1A1A1A)),
                    ),
                  ),
                  Text(
                      '× $qty  Rs. ${(price * qty).toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9B9B9B))),
                ],
              ),
            );
          }),
        ],
      ),
    );
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
          color: bg, borderRadius: BorderRadius.circular(20)),
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
}
