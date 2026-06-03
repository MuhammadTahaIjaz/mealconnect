import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../auth/controllers/auth_controller.dart';

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
      final schoolId = Get.find<AuthController>().schoolId.value;
      if (schoolId.isEmpty) { return; }

      final from = DateTime.now().subtract(const Duration(days: 29));
      final fromDate = DateTime(from.year, from.month, from.day);

      // ── Get this school's cafeteria IDs ────────────────────────────────
      final cafSnap = await _db
          .collection('cafeterias')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      final cafIds = cafSnap.docs.map((d) => d.id).toList();

      if (cafIds.isEmpty) {
        _setEmpty(fromDate);
        return;
      }

      // ── Fetch delivered mealSelections in batches of 30 ────────────────
      final allDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      const batchSize = 30;
      for (var i = 0; i < cafIds.length; i += batchSize) {
        final chunk =
            cafIds.sublist(i, (i + batchSize).clamp(0, cafIds.length));
        final snap = await _db
            .collection('mealSelections')
            .where('cafeteriaId', whereIn: chunk)
            .where('isDelivered', isEqualTo: true)
            .get();
        allDocs.addAll(snap.docs);
      }

      // ── Initialise a slot for every day in the 30-day window ──────────
      // key = 'yyyy-MM-dd', value = Set of unique orderIds for that day
      final Map<String, Set<String>> ordersByDay = {};
      for (var i = 0; i < 30; i++) {
        final day = fromDate.add(Duration(days: i));
        ordersByDay[_key(day)] = {};
      }

      final cutoff = fromDate;
      final allOrderIds = <String>{};

      for (final doc in allDocs) {
        final ts = doc.data()['deliveryDate'] as Timestamp?;
        if (ts == null) continue;
        final d = ts.toDate();
        if (d.isBefore(cutoff)) continue;

        final orderId =
            (doc.data()['orderId'] as String?)?.isNotEmpty == true
                ? doc.data()['orderId'] as String
                : doc.id;

        final k = _key(d);
        ordersByDay[k]?.add(orderId);
        allOrderIds.add(orderId);
      }

      // ── Build sorted daily list ────────────────────────────────────────
      final entries = ordersByDay.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      dailyDeliveries.value = entries.map((e) {
        final parts = e.key.split('-');
        return DailyDelivery(
          DateTime(int.parse(parts[0]), int.parse(parts[1]),
              int.parse(parts[2])),
          e.value.length, // unique orders for that day
        );
      }).toList();

      totalDeliveries.value = allOrderIds.length; // unique orders total
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  void _setEmpty(DateTime fromDate) {
    final entries = <DailyDelivery>[];
    for (var i = 0; i < 30; i++) {
      entries.add(DailyDelivery(fromDate.add(Duration(days: i)), 0));
    }
    dailyDeliveries.value = entries;
    totalDeliveries.value = 0;
    isLoading.value = false;
  }

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
