import 'package:get/get.dart';

class HomeController extends GetxController {
  final selectedIndex = 0.obs;

  final menuItems = [
    {'icon': 'dashboard', 'label': 'Dashboard'},
    {'icon': 'people', 'label': 'Verify Parents'},
    {'icon': 'store', 'label': 'Verify Cafeterias'},
    {'icon': 'manage_accounts', 'label': 'User Management'},
    {'icon': 'bar_chart', 'label': 'Delivery Reports'},
    {'icon': 'notifications', 'label': 'Notifications'},
  ];

  void selectIndex(int index) => selectedIndex.value = index;
}
