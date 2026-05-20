import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../auth/controllers/auth_controller.dart';

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
      final schoolId = Get.find<AuthController>().schoolId.value;

      Query<Map<String, dynamic>> parentsQ = _db
          .collection('parents')
          .where('accountStatus', isEqualTo: 'pending');
      Query<Map<String, dynamic>> cafeteriasQ = _db
          .collection('cafeterias')
          .where('isVerified', isEqualTo: false);
      Query<Map<String, dynamic>> usersQ = _db.collection('users');
      Query<Map<String, dynamic>> selectionsQ = _db
          .collection('mealSelections')
          .where('deliveryDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 30))));

      if (schoolId.isNotEmpty) {
        parentsQ     = parentsQ.where('schoolId', isEqualTo: schoolId);
        cafeteriasQ  = cafeteriasQ.where('schoolId', isEqualTo: schoolId);
        usersQ       = usersQ.where('schoolId', isEqualTo: schoolId);
        selectionsQ  = selectionsQ.where('schoolId', isEqualTo: schoolId);
      }

      final results = await Future.wait([
        parentsQ.count().get(),
        cafeteriasQ.count().get(),
        usersQ.count().get(),
        selectionsQ.count().get(),
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
