import 'package:get/get.dart';
import '../controllers/home_controller.dart';
import '../../parents/controllers/parents_controller.dart';
import '../../cafeterias/controllers/cafeterias_controller.dart';
import '../../users/controllers/users_controller.dart';
import '../../reports/controllers/reports_controller.dart';
import '../../notifications_section/controllers/notifications_controller.dart';
import '../../dashboard/controllers/dashboard_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(() => HomeController());
    Get.lazyPut<DashboardController>(() => DashboardController());
    Get.lazyPut<ParentsController>(() => ParentsController());
    Get.lazyPut<CafeteriasController>(() => CafeteriasController());
    Get.lazyPut<UsersController>(() => UsersController());
    Get.lazyPut<ReportsController>(() => ReportsController());
    Get.lazyPut<NotificationsController>(() => NotificationsController());
  }
}
