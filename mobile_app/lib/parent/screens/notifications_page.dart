import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationsPage extends StatelessWidget {
  final void Function(int tab)? onNavigateToTab;
  const NotificationsPage({super.key, this.onNavigateToTab});

  static const _pink = Color(0xFFFF3366);

  void _markAsRead(String docId) {
    FirebaseFirestore.instance
        .collection('notifications')
        .doc(docId)
        .update({'isRead': true});
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            const Text(
              'NOTIFICATIONS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('userId', isEqualTo: uid)
                    .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(
                      DateTime(DateTime.now().year, DateTime.now().month, 1),
                    ))
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_pink),
                      ),
                    );
                  }

                  final docs = ((snapshot.data?.docs) ?? [])
                      .where((doc) =>
                          (doc.data() as Map<String, dynamic>)['isRead'] != true)
                      .take(50)
                      .toList();

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined,
                              size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text(
                            'No notifications yet.',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF9B9B9B),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFF0F0F0)),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data =
                          doc.data() as Map<String, dynamic>;
                      return _buildNotificationItem(doc.id, data);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
      String docId, Map<String, dynamic> data) {
    final title = data['title'] as String? ?? '';
    final message = data['message'] as String? ?? '';
    final type = data['type'] as String? ?? '';
    final isRead = data['isRead'] as bool? ?? true;

    final bool hasDestination =
        type == 'child_approved' || type == 'child_rejected';

    return GestureDetector(
      onTap: (!isRead || hasDestination)
          ? () {
              if (!isRead) _markAsRead(docId);
              if (hasDestination) onNavigateToTab?.call(2);
            }
          : null,
      child: Container(
        color: isRead ? Colors.white : const Color(0xFFFFF8F8),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRead
                    ? const Color(0xFFF7F8FC)
                    : _pink.withValues(alpha: 0.10),
                border: Border.all(
                  color: isRead
                      ? const Color(0xFFEEEEEE)
                      : _pink.withValues(alpha: 0.30),
                ),
              ),
              child: Icon(
                Icons.notifications_outlined,
                size: 22,
                color: isRead
                    ? const Color(0xFF9B9B9B)
                    : _pink,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isRead
                            ? FontWeight.w500
                            : FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9B9B9B),
                    ),
                  ),
                  if (!isRead) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Tap to mark as read',
                      style: TextStyle(
                        fontSize: 11,
                        color: _pink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6, left: 8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _pink,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
