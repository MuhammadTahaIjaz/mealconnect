import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../../../widgets/custom_hover_button.dart';
import '../controllers/cafeterias_controller.dart';

class VerifyCafeteriasPage extends GetView<CafeteriasController> {
  const VerifyCafeteriasPage({super.key});

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
              'Verify Cafeterias',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Obx(() => Text(
                  '${controller.cafeterias.length} pending approval',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                )),
          ],
        ),
        IconButton(
          onPressed: controller.fetchPendingCafeterias,
          icon: const Icon(Icons.refresh, color: AppColors.primaryPink),
          tooltip: 'Refresh',
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
      if (controller.cafeterias.isEmpty) {
        return _buildEmptyState();
      }
      return ListView.separated(
        itemCount: controller.cafeterias.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _buildCafeteriaCard(controller.cafeterias[i]),
      );
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.store_outlined,
              size: 64, color: AppColors.success.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            'No pending cafeteria approvals',
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

  Widget _buildCafeteriaCard(CafeteriaRecord cafeteria) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
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
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.store, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cafeteria.cafeteriaName.isNotEmpty
                      ? cafeteria.cafeteriaName
                      : 'Unnamed Cafeteria',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Owner: ${cafeteria.ownerName.isNotEmpty ? cafeteria.ownerName : cafeteria.email}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _buildStatusBadge('Unverified'),
          const SizedBox(width: 16),
          _buildActionButton(
            label: 'Approve',
            color: AppColors.success,
            onTap: () => controller.approveCafeteria(cafeteria.cafeteriaId),
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            label: 'Reject',
            color: AppColors.error,
            onTap: () => controller.rejectCafeteria(cafeteria.cafeteriaId),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF856404),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final child = Text(
      label,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
    return CustomHoverButton(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      hoverDecoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: child,
    );
  }
}
