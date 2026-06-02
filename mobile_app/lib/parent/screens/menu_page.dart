import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Top-level helpers ────────────────────────────────────────────────────────

String _weekdayName(int weekday) {
  const n = [
    '', 'Monday', 'Tuesday', 'Wednesday',
    'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  return n[weekday];
}

String _shortMonth(int month) {
  const m = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return m[month];
}

// ── MenuPage ─────────────────────────────────────────────────────────────────

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  static const _pink = Color(0xFFFF3366);
  static const _orange = Color(0xFFFF8C00);

  late final String _childId;
  late final String _childName;
  late final String _schoolId;
  late final String _childRollNo;

  bool _initialized = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  static const _filterDays = [
    'All', 'Monday', 'Tuesday', 'Wednesday',
    'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  String _selectedFilterDay = 'All';

  // key = mealId, value = meal data + 'days': List<Map>
  final Map<String, Map<String, dynamic>> _cart = {};

  double get _cartTotal => _cart.values.fold(0.0, (s, item) {
        final days = (item['days'] as List<dynamic>?) ?? [];
        return s + days.fold<double>(0, (ds, d) {
          final day = d as Map<String, dynamic>;
          return ds +
              (item['price'] as num).toDouble() * (day['qty'] as int);
        });
      });

  int get _cartCount => _cart.values.fold(0, (s, item) {
        final days = (item['days'] as List<dynamic>?) ?? [];
        return s +
            days.fold<int>(0, (ds, d) => ds + ((d as Map)['qty'] as int));
      });

  // Returns tomorrow → end of current week (Sunday).
  // If today is Sunday, returns next Mon–Sun (7 days).
  List<DateTime> _getRemainingWeekDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int daysUntilSunday = DateTime.sunday - today.weekday;
    if (daysUntilSunday <= 0) daysUntilSunday += 7;
    final weekEnd = today.add(Duration(days: daysUntilSunday));
    final start = today.add(const Duration(days: 1));
    final days = <DateTime>[];
    for (var d = start; !d.isAfter(weekEnd);
        d = d.add(const Duration(days: 1))) {
      days.add(d);
    }
    return days;
  }

  List<DateTime> _getAvailableDays(
      List<DateTime> days, dynamic availability) {
    List<String> avail = [];
    if (availability is List) {
      avail = List<String>.from(availability);
    } else if (availability is String && availability.isNotEmpty) {
      avail = [availability];
    }
    if (avail.isEmpty) return days;
    return days.where((d) => avail.contains(_weekdayName(d.weekday))).toList();
  }

  Future<void> _openDaySelection(
      String mealId, Map<String, dynamic> data) async {
    final remaining = _getRemainingWeekDays();
    final available = _getAvailableDays(remaining, data['availability']);

    if (available.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${(data['mealName'] as String?) ?? 'This meal'} is not available in the remaining days of this week.'),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    final current = List<Map<String, dynamic>>.from(
      ((_cart[mealId]?['days'] as List<dynamic>?) ?? [])
          .map((d) => Map<String, dynamic>.from(d as Map)),
    );

    if (!mounted) return;
    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DaySelectionSheet(
        mealName: (data['mealName'] as String?) ?? 'Meal',
        price: (data['price'] as num?)?.toDouble() ?? 0.0,
        availableDays: available,
        initialSelection: current,
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      if (result.isEmpty) {
        _cart.remove(mealId);
      } else {
        _cart[mealId] = {...data, 'days': result};
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _childId = (args?['childId'] as String?) ?? '';
    _childName = (args?['name'] as String?) ?? 'Child';
    _schoolId = (args?['schoolId'] as String?) ?? '';
    _childRollNo = (args?['classRollNo'] as String?) ?? '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _goToCheckout() {
    final cartList = _cart.entries
        .map((e) => {
              'mealId': e.key,
              'mealName': (e.value['mealName'] as String?) ?? '',
              'price': (e.value['price'] as num?)?.toDouble() ?? 0.0,
              'cafeteriaId': (e.value['cafeteriaId'] as String?) ?? '',
              'imageUrl': (e.value['imageUrl'] as String?) ?? '',
              'days': e.value['days'],
            })
        .toList();

    Navigator.pushNamed(context, '/parent-checkout', arguments: {
      'cart': cartList,
      'childId': _childId,
      'childName': _childName,
      'childRollNo': _childRollNo,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      bottomNavigationBar:
          _cart.isEmpty ? null : _buildCheckoutBar(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            _buildSearchBar(),
            _buildDayFilter(),
            const SizedBox(height: 8),
            Expanded(child: _buildMealsGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [_pink, _orange]),
            ),
            child: Center(
              child: Text(
                '$_cartCount',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_cartCount item${_cartCount == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF9B9B9B)),
              ),
              Text(
                '\$${_cartTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A)),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _goToCheckout,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient:
                    const LinearGradient(colors: [_pink, _orange]),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                child: Text(
                  'Checkout',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios,
                  size: 16, color: Color(0xFF1A1A1A)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MENU',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  _childName,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF9B9B9B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) =>
              setState(() => _searchQuery = v.toLowerCase()),
          style: const TextStyle(
              fontSize: 14, color: Color(0xFF1A1A1A)),
          decoration: InputDecoration(
            hintText: 'Search meals...',
            hintStyle: const TextStyle(
                color: Color(0xFF9B9B9B), fontSize: 14),
            prefixIcon: const Icon(Icons.search,
                color: Color(0xFF9B9B9B), size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Icon(Icons.close,
                        color: Color(0xFF9B9B9B), size: 18),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildDayFilter() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
        itemCount: _filterDays.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final day = _filterDays[i];
          final selected = _selectedFilterDay == day;
          return GestureDetector(
            onTap: () =>
                setState(() => _selectedFilterDay = day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(
                        colors: [_pink, _orange])
                    : null,
                color: selected ? null : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                day,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: selected
                      ? Colors.white
                      : const Color(0xFF9B9B9B),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMealsGrid() {
    if (_schoolId.isEmpty) {
      return const Center(
        child: Text(
          'No school associated with this child.',
          style: TextStyle(
              color: Color(0xFF9B9B9B), fontSize: 14),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('meals')
          .where('schoolId', isEqualTo: _schoolId)
          .where('isAvailable', isEqualTo: true)
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

        final allDocs = snapshot.data?.docs ?? [];
        final filtered = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = ((data['mealName'] as String?) ?? '')
              .toLowerCase();
          if (_searchQuery.isNotEmpty &&
              !name.contains(_searchQuery)) return false;
          if (_selectedFilterDay != 'All') {
            final av = data['availability'];
            if (av is List) {
              if (!av.contains(_selectedFilterDay)) return false;
            } else if (av is String) {
              if (av != _selectedFilterDay) return false;
            } else {
              return false;
            }
          }
          return true;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant_menu_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text(
                  'No meals available.',
                  style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF9B9B9B)),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding:
              const EdgeInsets.fromLTRB(20, 4, 20, 20),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.72,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final doc = filtered[i];
            final data =
                doc.data() as Map<String, dynamic>;
            return _buildMealCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildMealCard(
      String mealId, Map<String, dynamic> data) {
    final name = (data['mealName'] as String?) ?? '';
    final price =
        (data['price'] as num?)?.toDouble() ?? 0.0;
    final imageUrl = (data['imageUrl'] as String?) ?? '';
    final av = data['availability'];
    String daysLabel = '';
    if (av is List && av.isNotEmpty) {
      daysLabel = av.length == 7
          ? 'All days'
          : av
              .map((d) => (d as String).substring(0, 3))
              .join(', ');
    } else if (av is String && av.isNotEmpty) {
      daysLabel = av.substring(0, 3);
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16)),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _imageFallback(),
                  )
                : _imageFallback(),
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (daysLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    daysLabel,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9B9B9B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _pink,
                      ),
                    ),
                    _buildCartControl(mealId, data),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartControl(
      String mealId, Map<String, dynamic> data) {
    final days =
        (_cart[mealId]?['days'] as List<dynamic>?) ?? [];

    if (days.isEmpty) {
      return GestureDetector(
        onTap: () => _openDaySelection(mealId, data),
        child: Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient:
                LinearGradient(colors: [_pink, _orange]),
          ),
          child: const Icon(Icons.add,
              color: Colors.white, size: 16),
        ),
      );
    }

    final totalQty = days.fold<int>(
        0, (s, d) => s + ((d as Map)['qty'] as int));
    final total =
        (data['price'] as num).toDouble() * totalQty;

    return GestureDetector(
      onTap: () => _openDaySelection(mealId, data),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(colors: [_pink, _orange]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${days.length}d·\$${total.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.edit,
                color: Colors.white, size: 11),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      height: 100,
      width: double.infinity,
      color: const Color(0xFFF7F8FC),
      child: const Icon(Icons.fastfood_outlined,
          size: 36, color: Color(0xFFCCCCCC)),
    );
  }
}

// ── Day Selection Bottom Sheet ────────────────────────────────────────────────

class _DaySelectionSheet extends StatefulWidget {
  final String mealName;
  final double price;
  final List<DateTime> availableDays;
  final List<Map<String, dynamic>> initialSelection;

  const _DaySelectionSheet({
    required this.mealName,
    required this.price,
    required this.availableDays,
    required this.initialSelection,
  });

  @override
  State<_DaySelectionSheet> createState() =>
      _DaySelectionSheetState();
}

class _DaySelectionSheetState extends State<_DaySelectionSheet> {
  static const _pink = Color(0xFFFF3366);
  static const _orange = Color(0xFFFF8C00);

  // key = 'yyyy-M-d', value = qty
  final Map<String, int> _sel = {};

  @override
  void initState() {
    super.initState();
    for (final item in widget.initialSelection) {
      final dt = item['date'] as DateTime;
      _sel[_key(dt)] = item['qty'] as int;
    }
  }

  String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

  double get _subtotal =>
      _sel.values.fold(0.0, (s, q) => s + widget.price * q);

  int get _totalItems =>
      _sel.values.fold(0, (s, q) => s + q);

  List<Map<String, dynamic>> _buildResult() {
    final result = <Map<String, dynamic>>[];
    for (final day in widget.availableDays) {
      final k = _key(day);
      if (_sel.containsKey(k)) {
        result.add({
          'date': day,
          'dayName': _weekdayName(day.weekday),
          'qty': _sel[k]!,
        });
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, insets + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEEE),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Text(
            widget.mealName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          Text(
            '\$${widget.price.toStringAsFixed(2)} per meal  •  Select delivery days',
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF9B9B9B)),
          ),
          const SizedBox(height: 16),
          // Day rows
          ...widget.availableDays.map((day) {
            final k = _key(day);
            final selected = _sel.containsKey(k);
            final qty = _sel[k] ?? 0;
            final label =
                '${_weekdayName(day.weekday)},  ${_shortMonth(day.month)} ${day.day}';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFFFF0F3)
                    : const Color(0xFFF7F8FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? _pink
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _sel.remove(k);
                      } else {
                        _sel[k] = 1;
                      }
                    }),
                    child: AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 150),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: selected
                            ? _pink
                            : Colors.white,
                        borderRadius:
                            BorderRadius.circular(6),
                        border: Border.all(
                          color: selected
                              ? _pink
                              : const Color(0xFFDDDDDD),
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              size: 14,
                              color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        color: selected
                            ? const Color(0xFF1A1A1A)
                            : const Color(0xFF9B9B9B),
                        fontWeight: selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (selected) ...[
                    _qtyBtn(
                      icon: Icons.remove,
                      onTap: () => setState(() {
                        if (qty <= 1) {
                          _sel.remove(k);
                        } else {
                          _sel[k] = qty - 1;
                        }
                      }),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '$qty',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    _qtyBtn(
                      icon: Icons.add,
                      onTap: () =>
                          setState(() => _sel[k] = qty + 1),
                    ),
                  ] else
                    const Text(
                      'Tap to select',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9B9B9B)),
                    ),
                ],
              ),
            );
          }),
          if (_sel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_totalItems item${_totalItems == 1 ? '' : 's'}  ·  ${_sel.length} day${_sel.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9B9B9B)),
                ),
                Text(
                  '\$${_subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _sel.isEmpty
                      ? [
                          const Color(0xFFCCCCCC),
                          const Color(0xFFCCCCCC)
                        ]
                      : const [_pink, _orange],
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: ElevatedButton(
                onPressed: _sel.isEmpty
                    ? null
                    : () =>
                        Navigator.pop(context, _buildResult()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(25)),
                ),
                child: Text(
                  _sel.isEmpty
                      ? 'Select at least one day'
                      : 'ADD TO CART',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _pink.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: _pink),
      ),
    );
  }
}
