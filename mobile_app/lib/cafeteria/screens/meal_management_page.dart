import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_meal_screen.dart';

class MealManagementPage extends StatefulWidget {
  const MealManagementPage({super.key});

  @override
  State<MealManagementPage> createState() => _MealManagementPageState();
}

class _MealManagementPageState extends State<MealManagementPage> {
  static const _pink = Color(0xFFFF3366);
  static const _orange = Color(0xFFFF8C00);

  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _schoolName = '';

  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadSchoolName();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSchoolName() async {
    try {
      final cafDoc = await FirebaseFirestore.instance
          .collection('cafeterias')
          .doc(_uid)
          .get();
      final schoolId = (cafDoc.data()?['schoolId'] as String?) ?? '';
      if (schoolId.isEmpty) return;
      final schoolDoc = await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .get();
      if (mounted) {
        setState(() {
          _schoolName =
              (schoolDoc.data()?['displayName'] as String?) ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleAvailability(String mealId, bool current) async {
    try {
      await FirebaseFirestore.instance
          .collection('meals')
          .doc(mealId)
          .update({'isAvailable': !current});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'SELECT MEAL',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Search Meal',
                    hintStyle: TextStyle(
                        color: Color(0xFF9B9B9B), fontSize: 14),
                    prefixIcon: Icon(Icons.search,
                        color: Color(0xFF9B9B9B), size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Meals list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('meals')
                    .where('cafeteriaId', isEqualTo: _uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_pink),
                      ),
                    );
                  }

                  final allDocs = snapshot.data?.docs ?? [];
                  final docs = _searchQuery.isEmpty
                      ? allDocs
                      : allDocs.where((d) {
                          final name =
                              ((d.data() as Map)['mealName'] as String? ??
                                      '')
                                  .toLowerCase();
                          return name.contains(_searchQuery);
                        }).toList();

                  // Empty state
                  if (allDocs.isEmpty) {
                    return _buildEmptyState();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_schoolName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20),
                          child: Text(
                            _schoolName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: docs.length,
                          itemBuilder: (context, i) {
                            final data = docs[i].data()
                                as Map<String, dynamic>;
                            return _buildMealCard(
                                docs[i].id, data);
                          },
                        ),
                      ),
                      _buildAddButton(),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _pink.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.restaurant_menu,
                  size: 40, color: _pink),
            ),
            const SizedBox(height: 20),
            const Text(
              'No meals added yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first meal to get started.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 14, color: Color(0xFF9B9B9B)),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_pink, _orange]),
                  borderRadius: BorderRadius.circular(27),
                ),
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/cafeteria-add-meal'),
                  icon: const Icon(Icons.add,
                      color: Colors.white, size: 20),
                  label: const Text(
                    'Add Your First Meal',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard(String mealId, Map<String, dynamic> data) {
    final name = (data['mealName'] as String?) ?? '';
    final price = (data['price'] as num?)?.toDouble() ?? 0;
    final isAvailable = (data['isAvailable'] as bool?) ?? true;
    final imageUrl = (data['imageUrl'] as String?) ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal image
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12)),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) =>
                          _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
          ),

          // Info
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Rs. ${price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9B9B9B),
                  ),
                ),
                Row(
                  children: [
                    Transform.scale(
                      scale: 0.7,
                      alignment: Alignment.centerLeft,
                      child: Switch(
                        value: isAvailable,
                        onChanged: (_) =>
                            _toggleAvailability(mealId, isAvailable),
                        activeThumbColor: const Color(0xFF43A047),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/cafeteria-edit-meal',
                        arguments: {'mealId': mealId, 'data': data},
                      ),
                      child: const Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFFF8C00),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFF0F0F0),
      child: const Center(
        child: Icon(Icons.restaurant, color: Color(0xFFCCCCCC), size: 28),
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      color: const Color(0xFFF7F8FC),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_pink, _orange]),
            borderRadius: BorderRadius.circular(27),
          ),
          child: ElevatedButton(
            onPressed: () =>
                Navigator.pushNamed(context, '/cafeteria-add-meal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(27),
              ),
            ),
            child: const Text(
              'ADD',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
