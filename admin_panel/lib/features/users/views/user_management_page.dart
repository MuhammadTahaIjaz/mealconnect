import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../controllers/users_controller.dart';

class UserManagementPage extends GetView<UsersController> {
  const UserManagementPage({super.key});

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
            const SizedBox(height: 20),
            _buildFilters(),
            const SizedBox(height: 16),
            Expanded(child: _buildTable()),
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
              'User Management',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Obx(() => Text(
                  '${controller.filteredUsers.length} users',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                )),
          ],
        ),
        IconButton(
          onPressed: controller.fetchUsers,
          icon: const Icon(Icons.refresh, color: AppColors.primaryPink),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        // Search
        Expanded(
          child: SizedBox(
            height: 44,
            child: TextField(
              onChanged: (v) => controller.searchQuery.value = v,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by name or email...',
                hintStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: AppColors.textSecondary),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.primaryPink, width: 1.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Role filter
        Obx(() => _buildRoleDropdown()),
      ],
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: controller.selectedRole.value,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
          items: controller.roles
              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
              .toList(),
          onChanged: (v) {
            if (v != null) controller.selectedRole.value = v;
          },
        ),
      ),
    );
  }

  Widget _buildTable() {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
            child: CircularProgressIndicator(color: AppColors.primaryPink));
      }
      if (controller.filteredUsers.isEmpty) {
        return const Center(
          child: Text(
            'No users found',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                color: AppColors.textSecondary),
          ),
        );
      }

      return Container(
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                  AppColors.primaryPink.withValues(alpha: 0.06)),
              dataRowColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) {
                  return AppColors.primaryPink.withValues(alpha: 0.03);
                }
                return null;
              }),
              columns: const [
                DataColumn(
                    label: Text('Name',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 13))),
                DataColumn(
                    label: Text('Email',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 13))),
                DataColumn(
                    label: Text('Role',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 13))),
              ],
              rows: controller.filteredUsers
                  .map((u) => DataRow(cells: [
                        DataCell(Text(u.name,
                            style: const TextStyle(
                                fontFamily: 'Poppins', fontSize: 13))),
                        DataCell(Text(u.email,
                            style: const TextStyle(
                                fontFamily: 'Poppins', fontSize: 13))),
                        DataCell(_buildRoleBadge(u.role)),
                      ]))
                  .toList(),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    switch (role) {
      case 'admin':
        color = AppColors.primaryPink;
        break;
      case 'parent':
        color = const Color(0xFF5C6BC0);
        break;
      case 'cafeteria':
        color = AppColors.primaryOrange;
        break;
      default:
        color = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role.isNotEmpty ? role : 'unknown',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
