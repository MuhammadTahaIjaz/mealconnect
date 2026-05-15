import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class CafeteriaRecord {
  final String cafeteriaId;
  final String userId;
  final String cafeteriaName;
  final String ownerName;
  final String email;
  final bool isVerified;
  final Timestamp? timestamp;

  CafeteriaRecord({
    required this.cafeteriaId,
    required this.userId,
    required this.cafeteriaName,
    required this.ownerName,
    required this.email,
    required this.isVerified,
    this.timestamp,
  });
}

class CafeteriasController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final cafeterias = <CafeteriaRecord>[].obs;
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    fetchPendingCafeterias();
  }

  Future<void> fetchPendingCafeterias() async {
    isLoading.value = true;
    try {
      final snapshot = await _db
          .collection('cafeterias')
          .where('isVerified', isEqualTo: false)
          .get();

      final records = <CafeteriaRecord>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] ?? '';
        String ownerName = '';
        String email = '';

        if (userId.isNotEmpty) {
          final userDoc = await _db.collection('users').doc(userId).get();
          if (userDoc.exists) {
            ownerName = userDoc.data()?['name'] ?? '';
            email = userDoc.data()?['email'] ?? '';
          }
        }

        records.add(CafeteriaRecord(
          cafeteriaId: doc.id,
          userId: userId,
          cafeteriaName: data['cafeteriaName'] ?? '',
          ownerName: ownerName,
          email: email,
          isVerified: data['isVerified'] ?? false,
          timestamp: data['timestamp'],
        ));
      }
      cafeterias.value = records;
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> approveCafeteria(String cafeteriaId) async {
    try {
      await _db
          .collection('cafeterias')
          .doc(cafeteriaId)
          .update({'isVerified': true});
      cafeterias.removeWhere((c) => c.cafeteriaId == cafeteriaId);
      Get.snackbar('Approved', 'Cafeteria has been verified.',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Error', 'Failed to approve cafeteria.');
    }
  }

  Future<void> rejectCafeteria(String cafeteriaId) async {
    try {
      await _db.collection('cafeterias').doc(cafeteriaId).delete();
      cafeterias.removeWhere((c) => c.cafeteriaId == cafeteriaId);
      Get.snackbar('Rejected', 'Cafeteria has been removed.',
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Error', 'Failed to reject cafeteria.');
    }
  }
}
