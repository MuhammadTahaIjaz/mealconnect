import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../app/services/notification_service.dart';
import '../../../app/services/email_service.dart';

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
  final isLoading      = true.obs;
  final processingIds  = <String>[].obs;

  StreamSubscription? _sub;

  @override
  void onInit() {
    super.onInit();
    fetchPendingParents();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  void fetchPendingParents() {
    final schoolId = Get.find<AuthController>().schoolId.value;
    var query = _db
        .collection('parents')
        .where('accountStatus', isEqualTo: 'pending');
    if (schoolId.isNotEmpty) {
      query = query.where('schoolId', isEqualTo: schoolId);
    }
    isLoading.value = true;
    _sub?.cancel();
    _sub = query.snapshots().listen((snapshot) async {
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
      isLoading.value = false;
    }, onError: (_) {
      isLoading.value = false;
    });
  }

  Future<void> updateStatus(String parentId, String status) async {
    processingIds.add(parentId);
    try {
      final parent = parents.firstWhere((p) => p.parentId == parentId);

      await _db
          .collection('parents')
          .doc(parentId)
          .update({'accountStatus': status});

      final title = status == 'approved'
          ? 'Account Approved'
          : 'Account Not Approved';
      final message = status == 'approved'
          ? 'Your MealConnect account has been approved. You can now sign in and use the app.'
          : 'Your account request was not approved. Please contact your school admin for more information.';

      await NotificationService.notifyUser(
        userId: parent.userId,
        title: title,
        message: message,
        type: 'account_$status',
      );

      await EmailService.sendParentStatusEmail(
        email: parent.email,
        name: parent.name,
        status: status,
      );

      // Stream will remove the record automatically; do it immediately too for snappy UI
      parents.removeWhere((p) => p.parentId == parentId);
      Get.snackbar(
        status == 'approved' ? 'Approved' : 'Rejected',
        'Parent account has been $status.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar('Error', 'Failed to update status.');
    } finally {
      processingIds.remove(parentId);
    }
  }
}
