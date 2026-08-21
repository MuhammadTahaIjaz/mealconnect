import 'dart:async';
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

  // Stripe
  String? _stripeAccountId;
  final Set<String> _delivering = {};
  StreamSubscription<DocumentSnapshot>? _cafeteriaSub;

  // Cafeteria info
  String _cafeteriaSchoolId = '';

  // Week day filter, selected day (default: today)
  late DateTime _selectedDay;

  // Student search
  final _searchController = TextEditingController();
  bool _isSearching = false;
  String? _searchError;
  Map<String, dynamic>? _foundChild;
  String? _foundChildId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _loadCafeteriaInfo();
  }

  @override
  void dispose() {
    _cafeteriaSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _loadCafeteriaInfo() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _cafeteriaSub = FirebaseFirestore.instance
        .collection('cafeterias')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      setState(() {
        _cafeteriaSchoolId =
            (doc.data()?['schoolId'] as String?) ?? '';
        _stripeAccountId =
            doc.data()?['stripeAccountId'] as String?;
      });
    });
  }

  // Returns Sun–Sat of the current week (week resets every Sunday)
  List<DateTime> _getCurrentWeekDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // weekday: Mon=1 … Sat=6, Sun=7 → 7%7=0, so Sunday stays put
    final sunday = today.subtract(Duration(days: today.weekday % 7));
    return List.generate(7, (i) => sunday.add(Duration(days: i)));
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _matchesSelectedDay(Map<String, dynamic> data) {
    final deliveryTs = data['deliveryDate'] as Timestamp?;
    if (deliveryTs == null) {
      // Old orders without deliveryDate: show on today
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      return _isSameDay(_selectedDay, today);
    }
    final d = deliveryTs.toDate();
    return _isSameDay(
        _selectedDay, DateTime(d.year, d.month, d.day));
  }

  Future<void> _searchChild() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = true;
      _searchError = null;
      _foundChild = null;
      _foundChildId = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('children')
          .where('mealConnectId', isEqualTo: query)
          .get();
      final matches = snap.docs
          .where((d) =>
              (d.data()['schoolId'] as String?) ==
              _cafeteriaSchoolId)
          .toList();
      if (!mounted) return;
      if (matches.isEmpty) {
        setState(() {
          _searchError =
              'No student found with this ID at your school.';
          _isSearching = false;
        });
        return;
      }
      setState(() {
        _foundChild = matches.first.data();
        _foundChildId = matches.first.id;
        _isSearching = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _searchError =
              'Search failed. Check your connection.';
          _isSearching = false;
        });
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _foundChild = null;
      _foundChildId = null;
      _searchError = null;
    });
  }

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
            'Connect your bank account in Settings → Bank Account first.'),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }
    setState(() => _delivering.add(orderId));
    try {
      double total = 0;
      for (final doc in items) {
        final data = doc.data() as Map<String, dynamic>;
        total += (data['price'] as num).toDouble() *
            (data['quantity'] as num).toInt();
      }
      final amountCents = (total * 100).toInt();

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
        throw jsonDecode(response.body)['error'] ??
            'Transfer failed';
      }

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Order delivered! Rs. ${total.toStringAsFixed(2)} sent to your account.'),
          backgroundColor: const Color(0xFF43A047),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFE53935),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
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
            _buildWeekFilter(),
            _buildSearchBar(),
            Expanded(
              child: _isSearching
                  ? const Center(
                      child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(_pink)))
                  : _searchError != null
                      ? _buildSearchError()
                      : StreamBuilder<QuerySnapshot>(
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
                                        AlwaysStoppedAnimation<Color>(
                                            _pink)));
                            }

                            var docs = snapshot.data?.docs ?? [];

                            // Filter by selected day
                            docs = docs
                                .where((doc) => _matchesSelectedDay(
                                    doc.data()
                                        as Map<String, dynamic>))
                                .toList();

                            // Filter by found child if search active
                            if (_foundChildId != null) {
                              docs = docs
                                  .where((doc) =>
                                      (doc.data() as Map<String,
                                          dynamic>)['childId'] ==
                                      _foundChildId)
                                  .toList();
                            }

                            final grouped = _groupByOrder(docs);
                            final orderGroups =
                                grouped.entries.toList();

                            return ListView(
                              padding: const EdgeInsets.fromLTRB(
                                  20, 8, 20, 24),
                              children: [
                                if (_foundChild != null)
                                  _buildStudentCard(),
                                if (orderGroups.isEmpty)
                                  _buildEmptyState()
                                else
                                  ...orderGroups.map((e) => Padding(
                                        padding:
                                            const EdgeInsets.only(
                                                bottom: 12),
                                        child: _buildOrderCard(
                                            e.key, e.value),
                                      )),
                              ],
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
                color: Color(0xFF1A1A1A)),
          ),
          SizedBox(height: 4),
          Text(
            'Tap deliver when meal is handed to the student',
            style: TextStyle(fontSize: 12, color: Color(0xFF9B9B9B)),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekFilter() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekDays = _getCurrentWeekDays();
    const shortDay = [
      '', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    ];

    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
        itemCount: weekDays.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final day = weekDays[i];
          final isPast = day.isBefore(today);
          final isToday = _isSameDay(day, today);
          final isSelected = _isSameDay(day, _selectedDay);

          return GestureDetector(
            onTap: isPast ? null : () => setState(() => _selectedDay = day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 50,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: [_pink, _orange])
                    : null,
                color: isSelected
                    ? null
                    : isPast
                        ? const Color(0xFFF0F0F0)
                        : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isSelected || isPast
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    shortDay[day.weekday],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : isPast
                              ? const Color(0xFFCCCCCC)
                              : const Color(0xFF9B9B9B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : isPast
                              ? const Color(0xFFCCCCCC)
                              : const Color(0xFF1A1A1A),
                    ),
                  ),
                  if (isToday)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? Colors.white70
                            : _pink,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchChild(),
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF1A1A1A)),
                decoration: InputDecoration(
                  hintText: 'Search by MealConnect ID…',
                  hintStyle: const TextStyle(
                      color: Color(0xFF9B9B9B), fontSize: 14),
                  prefixIcon: const Icon(Icons.badge_outlined,
                      color: Color(0xFF9B9B9B), size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: _clearSearch,
                          child: const Icon(Icons.close,
                              color: Color(0xFF9B9B9B), size: 18),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: _pink, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _searchChild,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_pink, _orange]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.search,
                  color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_outlined,
                size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            Text(_searchError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF9B9B9B))),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard() {
    final name =
        (_foundChild!['name'] as String?) ?? 'Student';
    final rollNo =
        (_foundChild!['mealConnectId'] as String?) ?? '';
    final initial =
        name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient:
                  LinearGradient(colors: [_pink, _orange]),
            ),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A))),
                if (rollNo.isNotEmpty)
                  Text('ID: $rollNo',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9B9B9B))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle,
                    size: 12, color: Color(0xFF43A047)),
                SizedBox(width: 4),
                Text('Found',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF43A047))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Per-session cache: childId → mealConnectId Future (avoids duplicate reads)
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

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _foundChild != null
                ? Icons.check_circle_outline
                : Icons.pending_actions_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            _foundChild != null
                ? 'No pending orders for this student on this day.'
                : 'No pending orders for this day.',
            style: const TextStyle(
                fontSize: 15, color: Color(0xFF9B9B9B)),
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
    final childId = firstData['childId'] as String? ?? '';
    final isDelivering = _delivering.contains(orderId);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isFuture = _selectedDay.isAfter(today);

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
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(childName,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A))),
                      _mealConnectIdLabel(childId),
                    ],
                  ),
                ),
                Text('Rs. ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _pink)),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(
                height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 10),
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
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.restaurant,
                        size: 16, color: Color(0xFF9B9B9B)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(mealName,
                            style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1A1A1A)))),
                    Text('× $qty',
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9B9B9B))),
                    const SizedBox(width: 12),
                    Text(
                        'Rs. ${(price * qty).toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A))),
                  ],
                ),
              );
            }),
            const SizedBox(height: 6),
            const Divider(
                height: 1, color: Color(0xFFF0F0F0)),
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
                                      _pink))))
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isFuture
                              ? [
                                  const Color(0xFFCCCCCC),
                                  const Color(0xFFCCCCCC)
                                ]
                              : const [_pink, _orange],
                        ),
                        borderRadius:
                            BorderRadius.circular(22),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: isFuture
                            ? null
                            : () => _markDelivered(
                                orderId, items),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(22)),
                        ),
                        icon: Icon(
                            isFuture
                                ? Icons.schedule_outlined
                                : Icons.check_circle_outline,
                            color: Colors.white,
                            size: 18),
                        label: Text(
                            isFuture
                                ? 'AVAILABLE ON DELIVERY DAY'
                                : 'MARK AS DELIVERED',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.8)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
