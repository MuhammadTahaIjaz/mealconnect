import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class DailyDelivery {
  final DateTime date;
  final int count;
  DailyDelivery(this.date, this.count);
}

class ReportsController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final dailyDeliveries = <DailyDelivery>[].obs;
  final totalDeliveries = 0.obs;
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    fetchDeliveryReport();
  }

  Future<void> fetchDeliveryReport() async {
    isLoading.value = true;
    try {
      final from = DateTime.now().subtract(const Duration(days: 29));
      final fromDate = DateTime(from.year, from.month, from.day);

      final snapshot = await _db
          .collection('mealSelections')
          .where('isDelivered', isEqualTo: true)
          .where('deliveryDate',
              isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate))
          .get();

      // Group by day
      final Map<String, int> countByDay = {};
      for (int i = 0; i < 30; i++) {
        final day = fromDate.add(Duration(days: i));
        final key =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        countByDay[key] = 0;
      }

      for (final doc in snapshot.docs) {
        final ts = doc.data()['deliveryDate'];
        if (ts is Timestamp) {
          final d = ts.toDate();
          final key =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          if (countByDay.containsKey(key)) {
            countByDay[key] = (countByDay[key] ?? 0) + 1;
          }
        }
      }

      final entries = countByDay.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      dailyDeliveries.value = entries.map((e) {
        final parts = e.key.split('-');
        return DailyDelivery(
          DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
          e.value,
        );
      }).toList();

      totalDeliveries.value = snapshot.docs.length;
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }
}
