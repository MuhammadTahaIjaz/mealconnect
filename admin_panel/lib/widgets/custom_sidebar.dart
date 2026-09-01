import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../app/theme/app_colors.dart';
import '../features/auth/controllers/auth_controller.dart';
import '../features/dashboard/controllers/dashboard_controller.dart';
import '../features/home/controllers/home_controller.dart';

class CustomSidebar extends StatelessWidget {
  const CustomSidebar({super.key});

  static const _width = 240.0;

  static const _items = [
    {
      'icon': Icons.dashboard_outlined,
      'activeIcon': Icons.dashboard,
      'label': 'Dashboard',
    },
    {
      'icon': Icons.people_outline,
      'activeIcon': Icons.people,
      'label': 'Verify Parents',
    },
    {
      'icon': Icons.store_outlined,
      'activeIcon': Icons.store,
      'label': 'Verify Cafeterias',
    },
    {
      'icon': Icons.child_care_outlined,
      'activeIcon': Icons.child_care,
      'label': 'Verify Children',
    },
    {
      'icon': Icons.manage_accounts_outlined,
      'activeIcon': Icons.manage_accounts,
      'label': 'User Management',
    },
    {
      'icon': Icons.bar_chart_outlined,
      'activeIcon': Icons.bar_chart,
      'label': 'Delivery Reports',
    },
    {
      'icon': Icons.notifications_outlined,
      'activeIcon': Icons.notifications,
      'label': 'Notifications',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final home = Get.find<HomeController>();
    final auth = Get.find<AuthController>();

    return Container(
      width: _width,
      color: Colors.white,
      child: Column(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => Get.find<HomeController>().selectIndex(0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 32,
                  horizontal: 20,
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/logos/mealconnectlogo.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'MealConnect',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),

          Expanded(
            child: SingleChildScrollView(
              child: Obx(() {
                // Safely read pending counts from DashboardController
                DashboardController? dash;
                try {
                  dash = Get.find<DashboardController>();
                } catch (_) {}

                return Column(
                  children: List.generate(_items.length, (i) {
                    final item = _items[i];
                    final isActive = home.selectedIndex.value == i;

                    // Verify items (1=Parents, 2=Cafeterias, 3=Children)
                    // are disabled when no pending requests exist
                    bool isDisabled = false;
                    if (dash != null) {
                      if (i == 1) {
                        isDisabled = dash.pendingParentsCount.value == 0;
                      } else if (i == 2) {
                        isDisabled = dash.pendingCafeteriasCount.value == 0;
                      } else if (i == 3) {
                        isDisabled = dash.pendingChildrenCount.value == 0;
                      }
                    }

                    return _SidebarItem(
                      icon: item['icon'] as IconData,
                      activeIcon: item['activeIcon'] as IconData,
                      label: item['label'] as String,
                      isActive: isActive,
                      isDisabled: isDisabled,
                      onTap: () => home.selectIndex(i),
                    );
                  }),
                );
              }),
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _ChangePasswordButton(auth: auth),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: _LogoutButton(onTap: auth.logout),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final bool isDisabled;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final showHighlight = widget.isActive || _hovered;
    final disabled = widget.isDisabled && !widget.isActive;

    // Hover colour: pink tint when normal, nothing when disabled
    final hoverBg = disabled
        ? Colors.transparent
        : AppColors.primaryPink.withValues(alpha: 0.07);
    final iconColor = widget.isActive
        ? Colors.white
        : (_hovered && !disabled)
        ? AppColors.primaryPink
        : AppColors.textSecondary;
    final textColor = iconColor;

    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: disabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            gradient: widget.isActive ? AppColors.primaryGradient : null,
            color: widget.isActive
                ? null
                : _hovered
                ? hoverBg
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                showHighlight ? widget.activeIcon : widget.icon,
                size: 20,
                color: iconColor,
              ),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: showHighlight ? FontWeight.w600 : FontWeight.w400,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordButton extends StatefulWidget {
  final AuthController auth;
  const _ChangePasswordButton({required this.auth});

  @override
  State<_ChangePasswordButton> createState() => _ChangePasswordButtonState();
}

class _ChangePasswordButtonState extends State<_ChangePasswordButton> {
  bool _hovered = false;

  void _showDialog() {
    showDialog(
      context: context,
      builder: (_) => _ChangePasswordDialog(auth: widget.auth),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _showDialog,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.primaryPink.withValues(alpha: 0.10)
                : AppColors.primaryPink.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 20, color: AppColors.primaryPink),
              const SizedBox(width: 12),
              Text(
                'Change Password',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: _hovered ? FontWeight.w600 : FontWeight.w500,
                  color: AppColors.primaryPink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  final AuthController auth;
  const _ChangePasswordDialog({required this.auth});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  String _error = '';

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text.trim();
    final newPass = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _error = 'New password must be at least 6 characters.');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'New passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });
    final err = await widget.auth.changePassword(
      currentPassword: current,
      newPassword: newPass,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _loading = false;
        _error = err;
      });
    } else {
      Navigator.pop(context);
      Get.snackbar(
        'Password Changed',
        'Please sign in again with your new password.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      );
      await widget.auth.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Change Password',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_currentCtrl, 'Current Password'),
            const SizedBox(height: 14),
            _field(_newCtrl, 'New Password'),
            const SizedBox(height: 14),
            _field(_confirmCtrl, 'Confirm New Password'),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _error,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: AppColors.textSecondary,
            ),
          ),
        ),
        TextButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryPink,
                  ),
                )
              : const Text(
                  'Update',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryPink,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      obscureText: true,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
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
            color: AppColors.primaryPink,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatefulWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.error.withValues(alpha: 0.14)
                : AppColors.error.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.logout, size: 20, color: AppColors.error),
              const SizedBox(width: 12),
              Text(
                'Logout',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: _hovered ? FontWeight.w600 : FontWeight.w500,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
