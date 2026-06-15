import 'dart:async';
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
  final String classLevel;
  final String section;
  final String rollNumber;
  final String parentName;
  final String parentEmail;

  ChildRecord({
    required this.childId,
    required this.parentId,
    required this.childName,
    required this.schoolName,
    required this.classLevel,
    required this.section,
    required this.rollNumber,
    required this.parentName,
    required this.parentEmail,
  });
}

class ChildrenController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final children = <ChildRecord>[].obs;
  final isLoading     = true.obs;
  final processingIds = <String>[].obs;

  StreamSubscription? _sub;

  @override
  void onInit() {
    super.onInit();
    fetchPendingChildren();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  void fetchPendingChildren() {
    final schoolId = Get.find<AuthController>().schoolId.value;
    var query = _db
        .collection('children')
        .where('verificationStatus', isEqualTo: 'pending');
    if (schoolId.isNotEmpty) {
      query = query.where('schoolId', isEqualTo: schoolId);
    }
    isLoading.value = true;
    _sub?.cancel();
    _sub = query.snapshots().listen((snapshot) async {
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
          classLevel: (data['classLevel'] as String?) ?? '',
          section: (data['section'] as String?) ?? '',
          rollNumber: (data['rollNumber'] as String?)
              ?? (data['classRollNo'] as String?) ?? '',
          parentName: parentName,
          parentEmail: parentEmail,
        ));
      }
      children.value = records;
      isLoading.value = false;
    }, onError: (_) {
      isLoading.value = false;
    });
  }

  Future<void> updateStatus(String childId, String status) async {
    processingIds.add(childId);
    try {
      final child = children.firstWhere((c) => c.childId == childId);

      // Block child approval if parent is not yet approved
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

      // Generate MealConnect ID on approval
      String mealConnectId = '';
      final Map<String, dynamic> updateData = {'verificationStatus': status};
      if (status == 'approved') {
        mealConnectId = _generateMealConnectId(
          classLevel: child.classLevel,
          section: child.section,
          rollNumber: child.rollNumber,
        );
        updateData['mealConnectId'] = mealConnectId;
      }

      await _db.collection('children').doc(childId).update(updateData);

      final title = status == 'approved'
          ? 'Child Verification Approved'
          : 'Child Verification Not Approved';
      final message = status == 'approved'
          ? '${child.childName} has been verified. MealConnect ID: $mealConnectId'
          : '${child.childName}\'s verification was not successful. Please check the details and resubmit.';

      await NotificationService.notifyUser(
        userId: child.parentId,
        title: title,
        message: message,
        type: 'child_$status',
      );

      // Stream will remove the record automatically; do it immediately too for snappy UI
      children.removeWhere((c) => c.childId == childId);
      Get.snackbar(
        status == 'approved' ? 'Approved' : 'Rejected',
        'Child verification has been $status.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar('Error', 'Failed to update status.');
    } finally {
      processingIds.remove(childId);
    }
  }

  String _generateMealConnectId({
    required String classLevel,
    required String section,
    required String rollNumber,
  }) {
    String prefix;
    switch (classLevel.toLowerCase().trim()) {
      case 'play group':
        prefix = 'PG';
        break;
      case 'nursery':
        prefix = 'N';
        break;
      case 'prep':
        prefix = 'P';
        break;
      default:
        prefix = classLevel.trim();
    }
    final sectionLetter = section.trim().isNotEmpty
        ? section.trim()[0].toUpperCase()
        : '';
    return '$prefix$sectionLetter${rollNumber.trim()}';
  }
}
