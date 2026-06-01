import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  static const _days = [
    'All', 'Monday', 'Tuesday', 'Wednesday',
    'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  String _selectedDay = 'All';

  // key = mealId, value = meal data map + '_qty' key
  final Map<String, Map<String, dynamic>> _cart = {};

  double get _cartTotal => _cart.values.fold(
      0, (s, m) => s + (m['price'] as num).toDouble() * (m['_qty'] as int));
  int get _cartCount =>
      _cart.values.fold(0, (s, m) => s + (m['_qty'] as int));

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

  void _addToCart(String mealId, Map<String, dynamic> data) {
    setState(() {
      if (_cart.containsKey(mealId)) {
        _cart[mealId]!['_qty'] = (_cart[mealId]!['_qty'] as int) + 1;
      } else {
        _cart[mealId] = {...data, '_qty': 1};
      }
    });
  }

  void _removeFromCart(String mealId) {
    setState(() {
      final qty = (_cart[mealId]?['_qty'] as int?) ?? 0;
      if (qty <= 1) {
        _cart.remove(mealId);
      } else {
        _cart[mealId]!['_qty'] = qty - 1;
      }
    });
  }

  void _goToCheckout() {
    final cartList = _cart.entries
        .map((e) => {
              'mealId': e.key,
              'mealName': (e.value['mealName'] as String?) ?? '',
              'price': (e.value['price'] as num?)?.toDouble() ?? 0.0,
              'qty': e.value['_qty'] as int,
              'cafeteriaId': (e.value['cafeteriaId'] as String?) ?? '',
              'imageUrl': (e.value['imageUrl'] as String?) ?? '',
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
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF9B9B9B)),
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
                    fontSize: 13,
                    color: Color(0xFF9B9B9B),
                  ),
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
          style:
              const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
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
        itemCount: _days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final day = _days[i];
          final selected = _selectedDay == day;
          return GestureDetector(
            onTap: () => setState(() => _selectedDay = day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 6),
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
                day,
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
        },
      ),
    );
  }

  Widget _buildMealsGrid() {
    if (_schoolId.isEmpty) {
      return const Center(
        child: Text(
          'No school associated with this child.',
          style: TextStyle(color: Color(0xFF9B9B9B), fontSize: 14),
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_pink),
            ),
          );
        }

        final allDocs = snapshot.data?.docs ?? [];

        final filtered = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name =
              ((data['mealName'] as String?) ?? '').toLowerCase();
          if (_searchQuery.isNotEmpty &&
              !name.contains(_searchQuery)) {
            return false;
          }
          if (_selectedDay != 'All') {
            final av = data['availability'];
            if (av is List) {
              if (!av.contains(_selectedDay)) return false;
            } else if (av is String) {
              if (av != _selectedDay) return false;
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
                      fontSize: 15, color: Color(0xFF9B9B9B)),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
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
            final data = doc.data() as Map<String, dynamic>;
            return _buildMealCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildMealCard(String mealId, Map<String, dynamic> data) {
    final name = (data['mealName'] as String?) ?? '';
    final price = (data['price'] as num?)?.toDouble() ?? 0.0;
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
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imageFallback(),
                  )
                : _imageFallback(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
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
                        fontSize: 11, color: Color(0xFF9B9B9B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _pink,
                      ),
                    ),
                    _buildQtyControl(mealId, data),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyControl(String mealId, Map<String, dynamic> data) {
    final qty = (_cart[mealId]?['_qty'] as int?) ?? 0;

    if (qty == 0) {
      return GestureDetector(
        onTap: () => _addToCart(mealId, data),
        child: Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [_pink, _orange]),
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 16),
        ),
      );
    }

    return Container(
      height: 28,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_pink, _orange]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _removeFromCart(mealId),
            child: const SizedBox(
              width: 28,
              height: 28,
              child: Icon(Icons.remove, color: Colors.white, size: 14),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '$qty',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ),
          GestureDetector(
            onTap: () => _addToCart(mealId, data),
            child: const SizedBox(
              width: 28,
              height: 28,
              child: Icon(Icons.add, color: Colors.white, size: 14),
            ),
          ),
        ],
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
