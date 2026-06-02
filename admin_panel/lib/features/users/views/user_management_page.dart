import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../controllers/users_controller.dart';

class UserManagementPage extends GetView<UsersController> {
  const UserManagementPage({super.key});

  // ── Column flex weights ───────────────────────────────────────────────────
  static const _flexName   = 3;
  static const _flexEmail  = 4;
  static const _flexRole   = 2;
  static const _actionW    = 80.0;

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
            Expanded(child: _buildTable(context)),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

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

  // ── Filters ───────────────────────────────────────────────────────────────

  Widget _buildFilters() {
    return Row(
      children: [
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

  // ── Table ─────────────────────────────────────────────────────────────────

  Widget _buildTable(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(
            child: CircularProgressIndicator(
                color: AppColors.primaryPink));
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
          child: Column(
            children: [
              // Header row
              _buildHeaderRow(),
              const Divider(height: 1, color: AppColors.divider),
              // Data rows
              Expanded(
                child: ListView.separated(
                  itemCount: controller.filteredUsers.length,
                  separatorBuilder: (context, index) => const Divider(
                      height: 1, color: AppColors.divider),
                  itemBuilder: (ctx, i) => _buildUserRow(
                      ctx, controller.filteredUsers[i]),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildHeaderRow() {
    const style = TextStyle(
      fontFamily: 'Poppins',
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary,
      letterSpacing: 0.5,
    );
    return Container(
      color: AppColors.primaryPink.withValues(alpha: 0.05),
      padding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: _flexName,  child: const Text('NAME',   style: style)),
          Expanded(flex: _flexEmail, child: const Text('EMAIL',  style: style)),
          Expanded(flex: _flexRole,  child: const Text('ROLE',   style: style)),
          SizedBox(width: _actionW,  child: const Text('ACTION', style: style,
              textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildUserRow(BuildContext context, UserRecord user) {
    return Obx(() {
      final isDeleting = controller.deletingIds.contains(user.userId);

      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 24, vertical: 14),
        child: Row(
          children: [
            // Name
            Expanded(
              flex: _flexName,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        AppColors.primaryPink.withValues(alpha: 0.12),
                    child: Text(
                      user.name.isNotEmpty
                          ? user.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryPink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      user.name.isNotEmpty ? user.name : '—',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Email
            Expanded(
              flex: _flexEmail,
              child: Text(
                user.email,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Role badge
            Expanded(
              flex: _flexRole,
              child: _buildRoleBadge(user.role),
            ),
            // Delete button
            SizedBox(
              width: _actionW,
              child: Center(
                child: isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : _DeleteButton(
                        onTap: () =>
                            _confirmDelete(context, user),
                      ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ── Delete confirmation ───────────────────────────────────────────────────

  void _confirmDelete(BuildContext context, UserRecord user) {
    final isParent = user.role == 'parent';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Account',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          isParent
              ? 'This will permanently delete ${user.name}\'s account and all children registered under it. This cannot be undone.'
              : 'This will permanently delete ${user.name}\'s account. This cannot be undone.',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                  fontFamily: 'Poppins',
                  color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.deleteUser(user);
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

// ── Hoverable delete button ───────────────────────────────────────────────────

class _DeleteButton extends StatefulWidget {
  final VoidCallback onTap;
  const _DeleteButton({required this.onTap});

  @override
  State<_DeleteButton> createState() => _DeleteButtonState();
}

class _DeleteButtonState extends State<_DeleteButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.error.withValues(alpha: 0.12)
                : AppColors.error.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.delete_outline,
            size: 18,
            color: AppColors.error,
          ),
        ),
      ),
    );
  }
}
