import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../auth/controllers/auth_controller.dart';

class DashboardController extends GetxController {
  final _db   = FirebaseFirestore.instance;
  final _subs = <StreamSubscription>[];

  // Pending counts — real-time
  final pendingParentsCount    = 0.obs;
  final pendingCafeteriasCount = 0.obs;
  final pendingChildrenCount   = 0.obs;

  // Approved/active totals — real-time
  // Only approved users count as "total users"
  final totalParentsCount    = 0.obs;
  final totalCafeteriasCount = 0.obs;
  final totalChildrenCount   = 0.obs;

  // Deliveries — one-time fetch (complex aggregation)
  final deliveriesThisMonth  = 0.obs;
  final isLoadingDeliveries  = true.obs;

  // Kept for the dashboard isLoading guard (true until first stream data arrives)
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    _setupStreams();
    _fetchDeliveries();
  }

  @override
  void onClose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.onClose();
  }

  // ── Real-time streams ────────────────────────────────────────────────────

  void _setupStreams() {
    final schoolId = Get.find<AuthController>().schoolId.value;
    if (schoolId.isEmpty) {
      isLoading.value = false;
      return;
    }

    // Track how many streams have emitted at least once
    int streamsReady = 0;
    void markReady() {
      streamsReady++;
      if (streamsReady >= 6) isLoading.value = false;
    }

    // Pending parents
    _subs.add(_db.collection('parents')
        .where('schoolId', isEqualTo: schoolId)
        .where('accountStatus', isEqualTo: 'pending')
        .snapshots()
        .listen((s) {
      pendingParentsCount.value = s.docs.length;
      markReady();
    }, onError: (_) => markReady()));

    // Approved parents only → total
    _subs.add(_db.collection('parents')
        .where('schoolId', isEqualTo: schoolId)
        .where('accountStatus', isEqualTo: 'approved')
        .snapshots()
        .listen((s) {
      totalParentsCount.value = s.docs.length;
      markReady();
    }, onError: (_) => markReady()));

    // Pending cafeterias
    _subs.add(_db.collection('cafeterias')
        .where('schoolId', isEqualTo: schoolId)
        .where('isVerified', isEqualTo: false)
        .snapshots()
        .listen((s) {
      pendingCafeteriasCount.value = s.docs.length;
      markReady();
    }, onError: (_) => markReady()));

    // Verified cafeterias only → total
    _subs.add(_db.collection('cafeterias')
        .where('schoolId', isEqualTo: schoolId)
        .where('isVerified', isEqualTo: true)
        .snapshots()
        .listen((s) {
      totalCafeteriasCount.value = s.docs.length;
      markReady();
    }, onError: (_) => markReady()));

    // Pending children
    _subs.add(_db.collection('children')
        .where('schoolId', isEqualTo: schoolId)
        .where('verificationStatus', isEqualTo: 'pending')
        .snapshots()
        .listen((s) {
      pendingChildrenCount.value = s.docs.length;
      markReady();
    }, onError: (_) => markReady()));

    // Approved children only → total
    _subs.add(_db.collection('children')
        .where('schoolId', isEqualTo: schoolId)
        .where('verificationStatus', isEqualTo: 'approved')
        .snapshots()
        .listen((s) {
      totalChildrenCount.value = s.docs.length;
      markReady();
    }, onError: (_) => markReady()));
  }

  // ── Deliveries (one-time, complex aggregation) ───────────────────────────

  Future<void> _fetchDeliveries() async {
    isLoadingDeliveries.value = true;
    try {
      final schoolId = Get.find<AuthController>().schoolId.value;
      if (schoolId.isEmpty) { return; }

      final cutoff = DateTime.now().subtract(const Duration(days: 30));

      final cafSnap = await _db.collection('cafeterias')
          .where('schoolId', isEqualTo: schoolId)
          .get();
      final cafIds = cafSnap.docs.map((d) => d.id).toList();

      if (cafIds.isEmpty) {
        deliveriesThisMonth.value = 0;
        return;
      }

      final orderIds = <String>{};
      const batchSize = 30;
      for (var i = 0; i < cafIds.length; i += batchSize) {
        final chunk =
            cafIds.sublist(i, (i + batchSize).clamp(0, cafIds.length));
        final snap = await _db
            .collection('mealSelections')
            .where('cafeteriaId', whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final data = doc.data();
          if (data['isDelivered'] != true) continue;
          final ts = data['deliveryDate'] as Timestamp?;
          if (ts == null || !ts.toDate().isAfter(cutoff)) continue;
          final orderId = data['orderId'] as String?;
          orderIds.add(
              (orderId?.isNotEmpty == true) ? orderId! : doc.id);
        }
      }
      deliveriesThisMonth.value = orderIds.length;
    } catch (_) {
    } finally {
      isLoadingDeliveries.value = false;
    }
  }

  // Called by the Refresh Stats button and the quick-action refresh card
  Future<void> fetchStats() async {
    await _fetchDeliveries();
  }
}
