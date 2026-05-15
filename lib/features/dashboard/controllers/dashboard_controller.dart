import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class DashboardController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final pendingParentsCount = 0.obs;
  final pendingCafeteriasCount = 0.obs;
  final totalUsersCount = 0.obs;
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
      final results = await Future.wait([
        _db
            .collection('parents')
            .where('accountStatus', isEqualTo: 'pending')
            .count()
            .get(),
        _db
            .collection('cafeterias')
            .where('isVerified', isEqualTo: false)
            .count()
            .get(),
        _db.collection('users').count().get(),
        _db
            .collection('mealSelections')
            .where('deliveryDate',
                isGreaterThanOrEqualTo: Timestamp.fromDate(
                    DateTime.now().subtract(const Duration(days: 30))))
            .count()
            .get(),
      ]);

      pendingParentsCount.value = results[0].count ?? 0;
      pendingCafeteriasCount.value = results[1].count ?? 0;
      totalUsersCount.value = results[2].count ?? 0;
      deliveriesThisMonth.value = results[3].count ?? 0;
    } catch (e) {
      // Stats remain 0 if Firestore collections don't exist yet
    } finally {
      isLoading.value = false;
    }
  }
}
