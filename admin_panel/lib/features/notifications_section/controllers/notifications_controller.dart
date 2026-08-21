import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../home/controllers/home_controller.dart';

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

  StreamSubscription? _sub;

  @override
  void onInit() {
    super.onInit();
    _subscribe();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  void _subscribe() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    final now = DateTime.now();
    final startOfMonth = Timestamp.fromDate(DateTime(now.year, now.month, 1));

    isLoading.value = true;

    _sub = _db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('timestamp', isGreaterThanOrEqualTo: startOfMonth)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      // Only show unread; read notifications are removed from this page
      notifications.value = snapshot.docs
          .where((doc) => doc.data()['isRead'] != true)
          .map((doc) {
        final data = doc.data();
        return NotificationRecord(
          id: doc.id,
          title: data['title'] ?? '',
          message: data['message'] ?? '',
          type: data['type'] ?? '',
          isRead: false,
          timestamp: data['timestamp'],
        );
      }).toList();

      unreadCount.value = notifications.length;
      isLoading.value = false;
    }, onError: (_) {
      isLoading.value = false;
    });
  }

  Future<void> markAsRead(String id) async {
    try {
      await _db.collection('notifications').doc(id).update({'isRead': true});
    } catch (_) {}
  }

  void handleTap(NotificationRecord n) {
    markAsRead(n.id);
    final index = _pageIndexForType(n.type);
    if (index != null) Get.find<HomeController>().selectIndex(index);
  }

  int? _pageIndexForType(String type) => switch (type) {
    'new_parent_request' => 1,
    'new_cafeteria_request' => 2,
    'new_child_request' || 'child_update_request' => 3,
    _ => null,
  };

  Future<void> markAllRead() async {
    try {
      final batch = _db.batch();
      for (final n in notifications) {
        batch.update(_db.collection('notifications').doc(n.id), {'isRead': true});
      }
      await batch.commit();
    } catch (_) {}
  }
}
