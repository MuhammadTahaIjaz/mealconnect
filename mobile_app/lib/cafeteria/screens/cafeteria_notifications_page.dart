import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CafeteriaNotificationsPage extends StatelessWidget {
  const CafeteriaNotificationsPage({super.key});

  static const _pink = Color(0xFFFF3366);

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
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('userId', isEqualTo: uid)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(_pink),
                      ),
                    );
                  }
                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined,
                              size: 64,
                              color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text(
                            'No notifications yet.',
                            style: TextStyle(
                                fontSize: 15,
                                color: Color(0xFF9B9B9B)),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: snapshot.data!.docs.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 1),
                    itemBuilder: (context, i) {
                      final data = snapshot.data!.docs[i].data()
                          as Map<String, dynamic>;
                      final title = (data['title'] as String?) ?? '';
                      final message =
                          (data['message'] as String?) ?? '';
                      final isRead =
                          (data['isRead'] as bool?) ?? true;
                      return Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFF7F8FC),
                                border: Border.all(
                                    color: const Color(0xFFEEEEEE)),
                              ),
                              child: const Icon(
                                  Icons.notifications_outlined,
                                  size: 22,
                                  color: Color(0xFF9B9B9B)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  if (title.isNotEmpty)
                                    Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isRead
                                            ? FontWeight.w500
                                            : FontWeight.w700,
                                        color:
                                            const Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  const SizedBox(height: 2),
                                  Text(
                                    message,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF9B9B9B)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(
                                    top: 4, left: 8),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _pink,
                                ),
                              ),
                          ],
                        ),
                      );
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
}
