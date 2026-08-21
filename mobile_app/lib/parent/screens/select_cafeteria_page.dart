import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SelectCafeteriaPage extends StatefulWidget {
  const SelectCafeteriaPage({super.key});

  @override
  State<SelectCafeteriaPage> createState() => _SelectCafeteriaPageState();
}

class _SelectCafeteriaPageState extends State<SelectCafeteriaPage> {
  static const _pink = Color(0xFFFF3366);

  late final String _childId;
  late final String _childName;
  late final String _schoolId;
  late final String _mealConnectId;
  bool _initialized = false;

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
    _mealConnectId = (args?['mealConnectId'] as String?) ?? '';
  }

  void _selectCafeteria(String cafeteriaId, String cafeteriaName) {
    Navigator.pushNamed(context, '/parent-menu', arguments: {
      'childId': _childId,
      'name': _childName,
      'schoolId': _schoolId,
      'mealConnectId': _mealConnectId,
      'cafeteriaId': cafeteriaId,
      'cafeteriaName': cafeteriaName,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(child: _buildCafeteriaList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                  'SELECT CAFETERIA',
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

  Widget _buildCafeteriaList() {
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
          .collection('cafeterias')
          .where('schoolId', isEqualTo: _schoolId)
          .where('isVerified', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_pink),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text(
                  'No cafeterias available.',
                  style: TextStyle(fontSize: 15, color: Color(0xFF9B9B9B)),
                ),
                const SizedBox(height: 6),
                const Text(
                  'No verified cafeterias are set up for your school yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final cafId = docs[i].id;
            final cafName =
                (data['cafeteriaName'] as String?) ?? 'Cafeteria';
            return _CafeteriaCard(
              cafeteriaId: cafId,
              cafeteriaName: cafName,
              onTap: () => _selectCafeteria(cafId, cafName),
            );
          },
        );
      },
    );
  }
}

class _CafeteriaCard extends StatelessWidget {
  final String cafeteriaId;
  final String cafeteriaName;
  final VoidCallback onTap;

  const _CafeteriaCard({
    required this.cafeteriaId,
    required this.cafeteriaName,
    required this.onTap,
  });

  static const _pink = Color(0xFFFF3366);
  static const _orange = Color(0xFFFF8C00);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [_pink, _orange]),
              ),
              child: const Icon(Icons.storefront,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cafeteriaName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('meals')
                        .where('cafeteriaId', isEqualTo: cafeteriaId)
                        .where('isAvailable', isEqualTo: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Text(
                          'Loading meals...',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF9B9B9B)),
                        );
                      }
                      final count = snapshot.data!.docs.length;
                      return Text(
                        '$count meal${count == 1 ? '' : 's'} available',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9B9B9B)),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Color(0xFF9B9B9B), size: 22),
          ],
        ),
      ),
    );
  }
}
