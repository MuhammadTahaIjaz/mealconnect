import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class NotificationRecord {
  final String id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final Timestamp? timestamp;

  NotificationRecord({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.timestamp,
  });
}

class NotificationsController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final notifications = <NotificationRecord>[].obs;
  final isLoading = true.obs;
  final unreadCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    isLoading.value = true;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
      final snapshot = await _db
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      notifications.value = snapshot.docs.map((doc) {
        final data = doc.data();
        return NotificationRecord(
          id: doc.id,
          title: data['title'] ?? '',
          message: data['message'] ?? '',
          type: data['type'] ?? '',
          isRead: data['isRead'] ?? false,
          timestamp: data['timestamp'],
        );
      }).toList();

      unreadCount.value = notifications.where((n) => !n.isRead).length;
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> markAllRead() async {
    try {
      final batch = _db.batch();
      for (final n in notifications.where((n) => !n.isRead)) {
        batch.update(_db.collection('notifications').doc(n.id), {'isRead': true});
      }
      await batch.commit();
      notifications.value = notifications
          .map((n) => NotificationRecord(
                id: n.id,
                title: n.title,
                message: n.message,
                type: n.type,
                isRead: true,
                timestamp: n.timestamp,
              ))
          .toList();
      unreadCount.value = 0;
    } catch (_) {}
  }
}
