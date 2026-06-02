import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app/theme/app_colors.dart';
import '../controllers/notifications_controller.dart';

class NotificationsPage extends GetView<NotificationsController> {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Obx(() => Text(
                  '${controller.unreadCount.value} unread',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                )),
          ],
        ),
        Row(
          children: [
            TextButton(
              onPressed: controller.markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.primaryPink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              onPressed: controller.fetchNotifications,
              icon: const Icon(Icons.refresh, color: AppColors.primaryPink),
              tooltip: 'Refresh',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryPink));
      }
      if (controller.notifications.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_none_outlined,
                  size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              const Text(
                'No notifications yet',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }
      return ListView.separated(
        itemCount: controller.notifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) =>
            _buildNotificationCard(controller.notifications[i]),
      );
    });
  }

  Widget _buildNotificationCard(NotificationRecord n) {
    return MouseRegion(
      cursor: n.isRead
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: n.isRead ? null : () => controller.markAsRead(n.id),
        child: _NotificationCardContent(n: n),
      ),
    );
  }
}

class _NotificationCardContent extends StatefulWidget {
  final NotificationRecord n;
  const _NotificationCardContent({required this.n});

  @override
  State<_NotificationCardContent> createState() =>
      _NotificationCardContentState();
}

class _NotificationCardContentState
    extends State<_NotificationCardContent> {
  bool _hovered = false;

  Color _typeColor(String type) {
    switch (type) {
      case 'registration':
        return AppColors.primaryPink;
      case 'delivery':
        return AppColors.success;
      case 'payment':
        return AppColors.primaryOrange;
      default:
        return AppColors.accent;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'registration':
        return Icons.person_add_outlined;
      case 'delivery':
        return Icons.delivery_dining_outlined;
      case 'payment':
        return Icons.payment_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatTime(Timestamp ts) {
    final d = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.n;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: n.isRead
              ? (_hovered
                  ? const Color(0xFFFAFAFA)
                  : Colors.white)
              : (_hovered
                  ? AppColors.primaryPink.withValues(alpha: 0.08)
                  : AppColors.primaryPink.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: n.isRead
                ? AppColors.divider
                : AppColors.primaryPink.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _typeColor(n.type).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_typeIcon(n.type), color: _typeColor(n.type), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        n.title.isNotEmpty ? n.title : 'Notification',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight:
                              n.isRead ? FontWeight.w500 : FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (!n.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryPink,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  n.message,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (n.timestamp != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(n.timestamp!),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
