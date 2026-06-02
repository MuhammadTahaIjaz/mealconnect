import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../auth/controllers/auth_controller.dart';

class DashboardController extends GetxController {
  final _db = FirebaseFirestore.instance;

  // Pending counts
  final pendingParentsCount    = 0.obs;
  final pendingCafeteriasCount = 0.obs;
  final pendingChildrenCount   = 0.obs;

  // Total counts
  final totalParentsCount    = 0.obs;
  final totalCafeteriasCount = 0.obs;
  final totalChildrenCount   = 0.obs;

  // Deliveries (unique orders in last 30 days)
  final deliveriesThisMonth = 0.obs;

  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    fetchStats();
  }

  Future<void> fetchStats() async {
    isLoading.value = true;
    try {
      final schoolId = Get.find<AuthController>().schoolId.value;
      if (schoolId.isEmpty) { return; }

      // ── Parallel count queries ─────────────────────────────────────────
      final results = await Future.wait([
        // pending parents
        _db.collection('parents')
            .where('schoolId', isEqualTo: schoolId)
            .where('accountStatus', isEqualTo: 'pending')
            .count().get(),
        // pending cafeterias
        _db.collection('cafeterias')
            .where('schoolId', isEqualTo: schoolId)
            .where('isVerified', isEqualTo: false)
            .count().get(),
        // pending children
        _db.collection('children')
            .where('schoolId', isEqualTo: schoolId)
            .where('verificationStatus', isEqualTo: 'pending')
            .count().get(),
        // total parents
        _db.collection('parents')
            .where('schoolId', isEqualTo: schoolId)
            .count().get(),
        // total cafeterias
        _db.collection('cafeterias')
            .where('schoolId', isEqualTo: schoolId)
            .count().get(),
        // total children
        _db.collection('children')
            .where('schoolId', isEqualTo: schoolId)
            .count().get(),
      ]);

      pendingParentsCount.value    = results[0].count ?? 0;
      pendingCafeteriasCount.value = results[1].count ?? 0;
      pendingChildrenCount.value   = results[2].count ?? 0;
      totalParentsCount.value      = results[3].count ?? 0;
      totalCafeteriasCount.value   = results[4].count ?? 0;
      totalChildrenCount.value     = results[5].count ?? 0;

      // ── 30-day delivered orders (unique orderIds via cafeteriaIds) ────
      final cafSnap = await _db.collection('cafeterias')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      final cafIds = cafSnap.docs.map((d) => d.id).toList();

      if (cafIds.isEmpty) {
        deliveriesThisMonth.value = 0;
      } else {
        final cutoff = DateTime.now().subtract(const Duration(days: 30));
        final orderIds = <String>{};

        // Firestore 'in' max = 30 items
        const batchSize = 30;
        for (var i = 0; i < cafIds.length; i += batchSize) {
          final chunk = cafIds.sublist(
              i, (i + batchSize).clamp(0, cafIds.length));
          final snap = await _db
              .collection('mealSelections')
              .where('cafeteriaId', whereIn: chunk)
              .get();

          for (final doc in snap.docs) {
            final data = doc.data();
            if (data['isDelivered'] != true) continue;
            final deliveryTs = data['deliveryDate'] as Timestamp?;
            if (deliveryTs == null ||
                !deliveryTs.toDate().isAfter(cutoff)) continue;
            final orderId = data['orderId'] as String?;
            orderIds.add(
                (orderId?.isNotEmpty == true) ? orderId! : doc.id);
          }
        }
        deliveriesThisMonth.value = orderIds.length;
      }
    } catch (_) {
      // Stats remain 0 if collections don't exist yet
    } finally {
      isLoading.value = false;
    }
  }
}
