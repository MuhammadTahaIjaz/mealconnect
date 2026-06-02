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
    {'icon': Icons.dashboard_outlined,        'activeIcon': Icons.dashboard,        'label': 'Dashboard'},
    {'icon': Icons.people_outline,            'activeIcon': Icons.people,            'label': 'Verify Parents'},
    {'icon': Icons.store_outlined,            'activeIcon': Icons.store,             'label': 'Verify Cafeterias'},
    {'icon': Icons.child_care_outlined,       'activeIcon': Icons.child_care,        'label': 'Verify Children'},
    {'icon': Icons.manage_accounts_outlined,  'activeIcon': Icons.manage_accounts,   'label': 'User Management'},
    {'icon': Icons.bar_chart_outlined,        'activeIcon': Icons.bar_chart,         'label': 'Delivery Reports'},
    {'icon': Icons.notifications_outlined,    'activeIcon': Icons.notifications,     'label': 'Notifications'},
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
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
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
                      isDisabled =
                          dash.pendingParentsCount.value == 0;
                    } else if (i == 2) {
                      isDisabled =
                          dash.pendingCafeteriasCount.value == 0;
                    } else if (i == 3) {
                      isDisabled =
                          dash.pendingChildrenCount.value == 0;
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

          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.all(16),
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

    // Hover colour: pink when normal, grey when disabled
    final hoverBg = disabled
        ? const Color(0xFFF0F0F0)
        : AppColors.primaryPink.withValues(alpha: 0.07);
    final iconColor = widget.isActive
        ? Colors.white
        : (_hovered && !disabled)
            ? AppColors.primaryPink
            : AppColors.textSecondary;
    final textColor = iconColor;

    return MouseRegion(
      cursor: disabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
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
                  fontWeight:
                      showHighlight ? FontWeight.w600 : FontWeight.w400,
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
                  fontWeight:
                      _hovered ? FontWeight.w600 : FontWeight.w500,
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
