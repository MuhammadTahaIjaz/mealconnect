import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final _db = FirebaseFirestore.instance;

  // Writes a notification visible on the admin panel notifications page.
  static Future<void> notifyAdmin({
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      await _db.collection('notifications').add({
        'userId': 'admin',
        'title': title,
        'message': message,
        'type': type,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // Writes a notification for a specific parent user (shown in parent app).
  static Future<void> notifyUser({
    required String userId,
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      await _db.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
