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

  @override
  void onInit() {
    super.onInit();
    fetchPendingParents();
  }

  Future<void> fetchPendingParents() async {
    isLoading.value = true;
    try {
      final schoolId = Get.find<AuthController>().schoolId.value;
      var query = _db
          .collection('parents')
          .where('accountStatus', isEqualTo: 'pending');
      if (schoolId.isNotEmpty) {
        query = query.where('schoolId', isEqualTo: schoolId);
      }
      final snapshot = await query.get();

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
    processingIds.add(parentId);
    try {
      final parent = parents.firstWhere((p) => p.parentId == parentId);

      await _db
          .collection('parents')
          .doc(parentId)
          .update({'accountStatus': status});

      // Notify the parent in-app
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

      // Send email to the parent
      await EmailService.sendParentStatusEmail(
        email: parent.email,
        name: parent.name,
        status: status,
      );

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
