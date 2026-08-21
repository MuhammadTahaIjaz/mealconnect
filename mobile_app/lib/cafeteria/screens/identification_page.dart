import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IdentificationPage extends StatefulWidget {
  const IdentificationPage({super.key});

  @override
  State<IdentificationPage> createState() => _IdentificationPageState();
}

class _IdentificationPageState extends State<IdentificationPage> {
  static const _pink = Color(0xFFFF3366);
  static const _orange = Color(0xFFFF8C00);

  // Cafeteria context (loaded once on init)
  String _cafeteriaSchoolId = '';
  bool _infoLoaded = false;

  // Search
  final _searchController = TextEditingController();
  bool _isSearching = false;
  String? _searchError;

  // Found child
  Map<String, dynamic>? _foundChild;
  String? _foundChildId;

  // Per-order loading state
  final Set<String> _deliveringIds = {};

  @override
  void initState() {
    super.initState();
    _loadCafeteriaInfo();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCafeteriaInfo() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('cafeterias')
        .doc(uid)
        .get();
    if (!mounted) return;
    setState(() {
      _cafeteriaSchoolId =
          (doc.data()?['schoolId'] as String?) ?? '';
      _infoLoaded = true;
    });
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
          .where('classRollNo', isEqualTo: query)
          .get();

      // Filter by school client-side (avoids composite index requirement)
      final matches = snap.docs
          .where((d) =>
              (d.data()['schoolId'] as String?) == _cafeteriaSchoolId)
          .toList();

      if (matches.isEmpty) {
        setState(() {
          _searchError =
              'No child found with this ID at your school.';
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
      setState(() {
        _searchError = 'Search failed. Check your connection.';
        _isSearching = false;
      });
    }
  }

  Future<void> _markDelivered(
    String selectionId,
    double price,
    int qty,
    String parentId,
  ) async {
    setState(() => _deliveringIds.add(selectionId));

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // Mark the order as delivered
      batch.update(db.collection('mealSelections').doc(selectionId), {
        'isDelivered': true,
        'status': 'delivered',
        'deliveredAt': FieldValue.serverTimestamp(),
      });

      // Credit earnings to cafeteria
      final earned = price * qty;
      batch.update(db.collection('cafeterias').doc(uid), {
        'earnings': FieldValue.increment(earned),
      });

      await batch.commit();

      // Notify the parent
      final childName =
          (_foundChild?['name'] as String?) ?? 'your child';
      await db.collection('notifications').add({
        'userId': parentId,
        'title': 'Order Delivered',
        'message': 'Your order for $childName has been delivered.',
        'type': 'order_delivered',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update. Please try again.'),
            backgroundColor: Color(0xFFE53935),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deliveringIds.remove(selectionId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: !_infoLoaded
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_pink),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  _buildSearchBar(),
                  const SizedBox(height: 8),
                  Expanded(child: _buildContent()),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Center(
        child: Text(
          'IDENTIFICATION',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                    fontSize: 15, color: Color(0xFF1A1A1A)),
                decoration: const InputDecoration(
                  hintText: "Child's School ID…",
                  hintStyle: TextStyle(
                      color: Color(0xFF9B9B9B), fontSize: 14),
                  prefixIcon: Icon(Icons.badge_outlined,
                      color: Color(0xFF9B9B9B), size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: _pink, width: 1.5),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _searchChild,
            child: Container(
              width: 50,
              height: 50,
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

  Widget _buildContent() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_pink),
        ),
      );
    }

    if (_searchError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_outlined,
                size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            Text(
              _searchError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF9B9B9B)),
            ),
          ],
        ),
      );
    }

    if (_foundChild == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.badge_outlined,
                size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            const Text(
              'Enter a child\'s school ID above\nto view their pending orders.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Color(0xFF9B9B9B)),
            ),
          ],
        ),
      );
    }

    return _buildChildResults();
  }

  Widget _buildChildResults() {
    final name = (_foundChild!['name'] as String?) ?? 'Child';
    final schoolId =
        (_foundChild!['classRollNo'] as String?) ?? '';
    final schoolName =
        (_foundChild!['schoolName'] as String?) ?? '';
    final initial =
        name.isNotEmpty ? name[0].toUpperCase() : '?';
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        // ── Child info card ──────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDeco(),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_pink, _orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    if (schoolId.isNotEmpty)
                      Text(
                        'ID: $schoolId',
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9B9B9B)),
                      ),
                    if (schoolName.isNotEmpty)
                      Text(
                        schoolName,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9B9B9B)),
                      ),
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
                    Text(
                      'Found',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF43A047)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Orders section ───────────────────────────────────
        const Text(
          'Pending Orders',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 10),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('mealSelections')
              .where('childId', isEqualTo: _foundChildId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(_pink),
                  ),
                ),
              );
            }

            // Filter client-side: this cafeteria only, not yet delivered
            final docs =
                (snapshot.data?.docs ?? []).where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return d['cafeteriaId'] == uid &&
                  d['isDelivered'] == false;
            }).toList();

            if (docs.isEmpty) {
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(24),
                decoration: _cardDeco(),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 40, color: Color(0xFF43A047)),
                      SizedBox(height: 10),
                      Text(
                        'No pending orders.',
                        style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9B9B9B)),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                return _buildOrderCard(doc.id, d);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOrderCard(
      String selectionId, Map<String, dynamic> d) {
    final mealName = (d['mealName'] as String?) ?? 'Meal';
    final price = (d['price'] as num?)?.toDouble() ?? 0.0;
    final qty = (d['quantity'] as int?) ?? 1;
    final total = price * qty;
    final parentId = (d['parentId'] as String?) ?? '';
    final isDelivering = _deliveringIds.contains(selectionId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meal icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fastfood_outlined,
                    size: 22, color: Color(0xFFCCCCCC)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mealName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Qty: $qty  ×  Rs. ${price.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9B9B9B)),
                    ),
                  ],
                ),
              ),
              Text(
                'Rs. ${total.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _pink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(
              color: Color(0xFFF0F0F0), height: 1),
          const SizedBox(height: 12),
          // Mark Delivered button
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
                        valueColor: AlwaysStoppedAnimation<Color>(
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
                          selectionId, price, qty, parentId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(22),
                        ),
                      ),
                      icon: const Icon(
                          Icons.check_circle_outline,
                          color: Colors.white,
                          size: 18),
                      label: const Text(
                        'Mark as Delivered',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      );
}
