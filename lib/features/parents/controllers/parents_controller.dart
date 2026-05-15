import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class ParentRecord {
  final String parentId;
  final String userId;
  final String name;
  final String email;
  final String accountStatus;
  final Timestamp? timestamp;

  ParentRecord({
    required this.parentId,
    required this.userId,
    required this.name,
    required this.email,
    required this.accountStatus,
    this.timestamp,
  });
}

class ParentsController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final parents = <ParentRecord>[].obs;
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    fetchPendingParents();
  }

  Future<void> fetchPendingParents() async {
    isLoading.value = true;
    try {
      final snapshot = await _db
          .collection('parents')
          .where('accountStatus', isEqualTo: 'pending')
          .get();

      final records = <ParentRecord>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] ?? '';
        String name = '';
        String email = '';

        if (userId.isNotEmpty) {
          final userDoc = await _db.collection('users').doc(userId).get();
          if (userDoc.exists) {
            name = userDoc.data()?['name'] ?? '';
            email = userDoc.data()?['email'] ?? '';
          }
        }

        records.add(ParentRecord(
          parentId: doc.id,
          userId: userId,
          name: name,
          email: email,
          accountStatus: data['accountStatus'] ?? 'pending',
          timestamp: data['timestamp'],
        ));
      }
      parents.value = records;
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateStatus(String parentId, String status) async {
    try {
      await _db
          .collection('parents')
          .doc(parentId)
          .update({'accountStatus': status});
      parents.removeWhere((p) => p.parentId == parentId);
      Get.snackbar(
        status == 'approved' ? 'Approved' : 'Rejected',
        'Parent account has been $status.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to update status.');
    }
  }
}
