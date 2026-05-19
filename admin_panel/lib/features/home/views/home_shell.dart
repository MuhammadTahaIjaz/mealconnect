import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../widgets/custom_sidebar.dart';
import '../controllers/home_controller.dart';
import '../../dashboard/views/dashboard_page.dart';
import '../../parents/views/verify_parents_page.dart';
import '../../cafeterias/views/verify_cafeterias_page.dart';
import '../../children/views/verify_children_page.dart';
import '../../users/views/user_management_page.dart';
import '../../reports/views/delivery_reports_page.dart';
import '../../notifications_section/views/notifications_page.dart';

class HomeShell extends GetView<HomeController> {
  const HomeShell({super.key});

  Widget _pageAt(int index) {
    switch (index) {
      case 1: return const VerifyParentsPage();
      case 2: return const VerifyCafeteriasPage();
      case 3: return const VerifyChildrenPage();
      case 4: return const UserManagementPage();
      case 5: return const DeliveryReportsPage();
      case 6: return const NotificationsPage();
      default: return const DashboardPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const CustomSidebar(),
          Container(width: 1, color: const Color(0xFFEEEEEE)),
          Expanded(
            child: Obx(() => _pageAt(controller.selectedIndex.value)),
          ),
        ],
      ),
    );
  }
}
