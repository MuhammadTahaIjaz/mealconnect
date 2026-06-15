import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../app/services/notification_service.dart';
import '../../../app/services/email_service.dart';

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
  final isLoading     = true.obs;
  final processingIds = <String>[].obs;

  StreamSubscription? _sub;

  @override
  void onInit() {
    super.onInit();
    fetchPendingCafeterias();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  void fetchPendingCafeterias() {
    final schoolId = Get.find<AuthController>().schoolId.value;
    var query = _db
        .collection('cafeterias')
        .where('accountStatus', isEqualTo: 'pending');
    if (schoolId.isNotEmpty) {
      query = query.where('schoolId', isEqualTo: schoolId);
    }
    isLoading.value = true;
    _sub?.cancel();
    _sub = query.snapshots().listen((snapshot) async {
      final records = <CafeteriaRecord>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final userId = (data['userId'] as String?) ?? '';
        String ownerName = '';
        String email = '';

        if (userId.isNotEmpty) {
          final userDoc = await _db.collection('users').doc(userId).get();
          if (userDoc.exists) {
            ownerName = (userDoc.data()?['name'] as String?) ?? '';
            email = (userDoc.data()?['email'] as String?) ?? '';
          }
        }

        records.add(CafeteriaRecord(
          cafeteriaId: doc.id,
          userId: userId,
          cafeteriaName: (data['cafeteriaName'] as String?) ?? '',
          ownerName: ownerName,
          email: email,
          isVerified: (data['isVerified'] as bool?) ?? false,
          timestamp: data['timestamp'] as Timestamp?,
        ));
      }
      cafeterias.value = records;
      isLoading.value = false;
    }, onError: (_) {
      isLoading.value = false;
    });
  }

  Future<void> approveCafeteria(String cafeteriaId) async {
    processingIds.add(cafeteriaId);
    try {
      final cafeteria =
          cafeterias.firstWhere((c) => c.cafeteriaId == cafeteriaId);

      await _db.collection('cafeterias').doc(cafeteriaId).update({
        'isVerified': true,
        'accountStatus': 'approved',
      });

      await NotificationService.notifyUser(
        userId: cafeteria.userId,
        title: 'Cafeteria Approved',
        message:
            '${cafeteria.cafeteriaName} has been verified. You can now sign in and use the app.',
        type: 'cafeteria_approved',
      );

      await EmailService.sendParentStatusEmail(
        email: cafeteria.email,
        name: cafeteria.ownerName.isNotEmpty
            ? cafeteria.ownerName
            : cafeteria.cafeteriaName,
        status: 'approved',
      );

      // Stream will remove the record automatically; do it immediately too for snappy UI
      cafeterias.removeWhere((c) => c.cafeteriaId == cafeteriaId);
      Get.snackbar('Approved', 'Cafeteria has been verified.',
          snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar('Error', 'Failed to approve cafeteria.');
    } finally {
      processingIds.remove(cafeteriaId);
    }
  }

  Future<void> rejectCafeteria(String cafeteriaId) async {
    processingIds.add(cafeteriaId);
    try {
      final cafeteria =
          cafeterias.firstWhere((c) => c.cafeteriaId == cafeteriaId);

      await _db.collection('cafeterias').doc(cafeteriaId).update({
        'accountStatus': 'rejected',
      });

      await NotificationService.notifyUser(
        userId: cafeteria.userId,
        title: 'Cafeteria Not Approved',
        message:
            '${cafeteria.cafeteriaName}\'s registration was not approved. Please contact the school admin for more information.',
        type: 'cafeteria_rejected',
      );

      await EmailService.sendParentStatusEmail(
        email: cafeteria.email,
        name: cafeteria.ownerName.isNotEmpty
            ? cafeteria.ownerName
            : cafeteria.cafeteriaName,
        status: 'rejected',
      );

      // Stream will remove the record automatically; do it immediately too for snappy UI
      cafeterias.removeWhere((c) => c.cafeteriaId == cafeteriaId);
      Get.snackbar('Rejected', 'Cafeteria registration has been rejected.',
          snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      Get.snackbar('Error', 'Failed to reject cafeteria.');
    } finally {
      processingIds.remove(cafeteriaId);
    }
  }
}
