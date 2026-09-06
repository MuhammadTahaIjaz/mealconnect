import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../controllers/dashboard_controller.dart';
import '../../home/controllers/home_controller.dart';

class DashboardPage extends GetView<DashboardController> {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primaryPink));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildStatsSection(),
              const SizedBox(height: 40),
              _buildQuickActions(),
            ],
          ),
        );
      }),
    );
  }

  // Header

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dashboard',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Welcome back! Here\'s what\'s happening today.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // Stats

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: three combined cards
        Row(
          children: [
            Expanded(
              child: _buildCombinedCard(
                label: 'Parents',
                icon: Icons.people_outline,
                color: const Color(0xFFFF4B7B),
                total: controller.totalParentsCount.value,
                pending: controller.pendingParentsCount.value,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildCombinedCard(
                label: 'Cafeterias',
                icon: Icons.store_outlined,
                color: const Color(0xFFFF8C00),
                total: controller.totalCafeteriasCount.value,
                pending: controller.pendingCafeteriasCount.value,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildCombinedCard(
                label: 'Children',
                icon: Icons.child_care_outlined,
                color: const Color(0xFF5C6BC0),
                total: controller.totalChildrenCount.value,
                pending: controller.pendingChildrenCount.value,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Row 2: deliveries full-width
        _buildDeliveriesCard(),
      ],
    );
  }

  Widget _buildCombinedCard({
    required String label,
    required IconData icon,
    required Color color,
    required int total,
    required int pending,
  }) {
    final hasPending = pending > 0;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + label row
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 16),
          // Total + Pending row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$total',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                  width: 1, height: 40,
                  color: const Color(0xFFF0F0F0)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '$pending',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: hasPending
                                    ? AppColors.accent
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        if (hasPending) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Text(
                      'Pending',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveriesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: 28, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF26A69A).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delivery_dining_outlined,
                color: Color(0xFF26A69A), size: 24),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${controller.deliveriesThisMonth.value}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Orders delivered in the last 30 days',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Quick Actions

  Widget _buildQuickActions() {
    final pendingParents =
        controller.pendingParentsCount.value > 0;
    final pendingCafeterias =
        controller.pendingCafeteriasCount.value > 0;
    final pendingChildren =
        controller.pendingChildrenCount.value > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildActionButton(
              label: 'Verify Parents',
              icon: Icons.people,
              enabled: pendingParents,
              badgeCount: controller.pendingParentsCount.value,
              onTap: () =>
                  Get.find<HomeController>().selectIndex(1),
            ),
            _buildActionButton(
              label: 'Verify Cafeterias',
              icon: Icons.store,
              enabled: pendingCafeterias,
              badgeCount:
                  controller.pendingCafeteriasCount.value,
              onTap: () =>
                  Get.find<HomeController>().selectIndex(2),
            ),
            _buildActionButton(
              label: 'Verify Children',
              icon: Icons.child_care,
              enabled: pendingChildren,
              badgeCount: controller.pendingChildrenCount.value,
              onTap: () =>
                  Get.find<HomeController>().selectIndex(3),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return _ActionButton(
      label: label,
      icon: icon,
      enabled: enabled,
      badgeCount: badgeCount,
      onTap: onTap,
    );
  }
}

// Hoverable action button

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final int badgeCount;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled;

    return MouseRegion(
      cursor: active
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: active ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(
                    colors: _hovered
                        ? [
                            const Color(0xFFD93660),
                            const Color(0xFFD97400)
                          ]
                        : [
                            AppColors.primaryPink,
                            AppColors.primaryOrange
                          ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: active ? null : const Color(0xFFEEEEEE),
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.primaryPink.withValues(
                          alpha: _hovered ? 0.5 : 0.3),
                      blurRadius: _hovered ? 18 : 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: active
                    ? Colors.white
                    : const Color(0xFFAAAAAA),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? Colors.white
                      : const Color(0xFFAAAAAA),
                ),
              ),
              // Badge for pending count
              if (active && widget.badgeCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.badgeCount}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
