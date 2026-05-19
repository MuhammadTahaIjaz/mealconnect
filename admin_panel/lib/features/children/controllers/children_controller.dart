import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class ChildRecord {
  final String childId;
  final String parentId;
  final String childName;
  final String schoolName;
  final String classRollNo;
  final String parentName;
  final String parentEmail;

  ChildRecord({
    required this.childId,
    required this.parentId,
    required this.childName,
    required this.schoolName,
    required this.classRollNo,
    required this.parentName,
    required this.parentEmail,
  });
}

class ChildrenController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final children = <ChildRecord>[].obs;
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    fetchPendingChildren();
  }

  Future<void> fetchPendingChildren() async {
    isLoading.value = true;
    try {
      final snapshot = await _db
          .collection('children')
          .where('verificationStatus', isEqualTo: 'pending')
          .get();

      final records = <ChildRecord>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final parentId = (data['parentId'] as String?) ?? '';
        String parentName = '';
        String parentEmail = '';

        if (parentId.isNotEmpty) {
          final userDoc = await _db.collection('users').doc(parentId).get();
          if (userDoc.exists) {
            parentName = (userDoc.data()?['name'] as String?) ?? '';
            parentEmail = (userDoc.data()?['email'] as String?) ?? '';
          }
        }

        records.add(ChildRecord(
          childId: doc.id,
          parentId: parentId,
          childName: (data['name'] as String?) ?? '',
          schoolName: (data['schoolName'] as String?) ?? '',
          classRollNo: (data['classRollNo'] as String?) ?? '',
          parentName: parentName,
          parentEmail: parentEmail,
        ));
      }
      children.value = records;
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateStatus(String childId, String status) async {
    try {
      await _db
          .collection('children')
          .doc(childId)
          .update({'verificationStatus': status});
      children.removeWhere((c) => c.childId == childId);
      Get.snackbar(
        status == 'approved' ? 'Approved' : 'Rejected',
        'Child verification has been $status.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar('Error', 'Failed to update status.');
    }
  }
}
