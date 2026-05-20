import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../app/services/notification_service.dart';

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
      final schoolId = Get.find<AuthController>().schoolId.value;
      var query = _db
          .collection('children')
          .where('verificationStatus', isEqualTo: 'pending');
      if (schoolId.isNotEmpty) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      final snapshot = await query.get();

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
      final child = children.firstWhere((c) => c.childId == childId);

      // Block child approval if the parent account is not yet approved
      if (status == 'approved') {
        final parentDoc = await _db
            .collection('parents')
            .doc(child.parentId)
            .get();
        final parentStatus =
            (parentDoc.data()?['accountStatus'] as String?) ?? 'pending';

        if (parentStatus != 'approved') {
          final parentLabel = child.parentName.isNotEmpty
              ? child.parentName
              : child.parentEmail;
          Get.snackbar(
            'Parent Not Approved Yet',
            'Please approve $parentLabel\'s account first before approving this child.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFFFFF3CD),
            colorText: const Color(0xFF856404),
            duration: const Duration(seconds: 5),
          );
          return;
        }
      }

      await _db
          .collection('children')
          .doc(childId)
          .update({'verificationStatus': status});

      // Notify the parent in-app
      final title = status == 'approved'
          ? 'Child Verification Approved'
          : 'Child Verification Not Approved';
      final message = status == 'approved'
          ? '${child.childName}\'s school enrollment has been verified successfully.'
          : '${child.childName}\'s verification was not successful. Please check the details and resubmit.';

      await NotificationService.notifyUser(
        userId: child.parentId,
        title: title,
        message: message,
        type: 'child_$status',
      );

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
