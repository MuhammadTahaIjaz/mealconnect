import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../auth/controllers/auth_controller.dart';

const _backendUrl = 'http://72.61.254.215:3000';

class UserRecord {
  final String userId;
  final String name;
  final String email;
  final String role;
  final Timestamp? timestamp;
  final String? parentName;
  final String? parentId;
  final String? mealConnectId;

  UserRecord({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.timestamp,
    this.parentName,
    this.parentId,
    this.mealConnectId,
  });
}

class UsersController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final users = <UserRecord>[].obs;
  final filteredUsers = <UserRecord>[].obs;
  final isLoading = true.obs;
  final selectedRole = 'All'.obs;
  final searchQuery = ''.obs;
  final deletingIds = <String>[].obs;

  final roles = ['All', 'parent', 'cafeteria', 'child'];

  var _nonChildUsers = <UserRecord>[];
  var _parentNameMap = <String, String>{};
  StreamSubscription<QuerySnapshot>? _childrenSub;

  @override
  void onInit() {
    super.onInit();
    _loadData();
    ever(selectedRole, (_) => _applyFilter());
    ever(searchQuery, (_) => _applyFilter());
  }

  @override
  void onClose() {
    _childrenSub?.cancel();
    super.onClose();
  }

  Future<void> _loadData() async {
    isLoading.value = true;
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final schoolId = Get.find<AuthController>().schoolId.value;

      final usersSnap = await _db
          .collection('users')
          .where('schoolId', isEqualTo: schoolId)
          .get();

      final approvedParentsSnap = await _db
          .collection('parents')
          .where('schoolId', isEqualTo: schoolId)
          .where('accountStatus', isEqualTo: 'approved')
          .get();
      final approvedParentIds =
          approvedParentsSnap.docs.map((d) => d.id).toSet();

      final approvedCafeteriasSnap = await _db
          .collection('cafeterias')
          .where('schoolId', isEqualTo: schoolId)
          .where('accountStatus', isEqualTo: 'approved')
          .get();
      final approvedCafeteriaIds =
          approvedCafeteriasSnap.docs.map((d) => d.id).toSet();

      _nonChildUsers = usersSnap.docs
          .where((doc) {
            final d = doc.data();
            if (doc.id == currentUid || d['role'] == 'admin') return false;
            if (d['role'] == 'parent') return approvedParentIds.contains(doc.id);
            if (d['role'] == 'cafeteria') {
              return approvedCafeteriaIds.contains(doc.id);
            }
            return true;
          })
          .map((doc) {
            final d = doc.data();
            return UserRecord(
              userId: doc.id,
              name: d['name'] ?? '',
              email: d['email'] ?? '',
              role: d['role'] ?? '',
              timestamp: d['timestamp'],
            );
          })
          .toList();

      _parentNameMap = {for (final u in _nonChildUsers) u.userId: u.name};

      if (schoolId.isNotEmpty) {
        _childrenSub?.cancel();
        _childrenSub = _db
            .collection('children')
            .where('schoolId', isEqualTo: schoolId)
            .where('verificationStatus', isEqualTo: 'approved')
            .snapshots()
            .listen((snap) {
              final childRecords = snap.docs.map((doc) {
                final d = doc.data();
                final pid = d['parentId'] as String? ?? '';
                return UserRecord(
                  userId: doc.id,
                  name: d['name'] ?? '',
                  email: '',
                  role: 'child',
                  timestamp: d['createdAt'],
                  parentName: _parentNameMap[pid] ?? '',
                  parentId: pid,
                  mealConnectId: d['mealConnectId'] as String?,
                );
              }).toList();

              users.value = [..._nonChildUsers, ...childRecords];
              _applyFilter();
              if (isLoading.value) isLoading.value = false;
            });
      } else {
        users.value = [..._nonChildUsers];
        _applyFilter();
        isLoading.value = false;
      }
    } catch (_) {
      isLoading.value = false;
    }
  }

  void _applyFilter() {
    var list = users.toList();
    if (selectedRole.value != 'All') {
      list = list.where((u) => u.role == selectedRole.value).toList();
    }
    if (searchQuery.value.isNotEmpty) {
      final q = searchQuery.value.toLowerCase();
      list = list
          .where(
            (u) =>
                u.name.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q) ||
                (u.parentName?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
    filteredUsers.value = list;
  }

  Future<void> deleteUser(UserRecord user) async {
    if (deletingIds.contains(user.userId)) return;
    deletingIds.add(user.userId);
    try {
      final batch = _db.batch();

      if (user.role == 'child') {
        batch.delete(_db.collection('children').doc(user.userId));
        // Stream listener removes it from the list automatically
      } else {
        batch.delete(_db.collection('users').doc(user.userId));

        if (user.role == 'parent') {
          // Fetch stripeCustomerId before deleting the Firestore doc
          final parentDoc = await _db
              .collection('parents')
              .doc(user.userId)
              .get();
          final customerId = parentDoc.data()?['stripeCustomerId'] as String?;

          // Delete Stripe customer + Firebase Auth user via backend
          try {
            await http.post(
              Uri.parse('$_backendUrl/delete-parent'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'uid': user.userId, 'customerId': customerId}),
            );
          } catch (_) {
            // Backend unavailable, continue with Firestore cleanup
          }

          batch.delete(_db.collection('parents').doc(user.userId));
          final childrenSnap = await _db
              .collection('children')
              .where('parentId', isEqualTo: user.userId)
              .get();
          for (final doc in childrenSnap.docs) {
            batch.delete(doc.reference);
          }
        } else if (user.role == 'cafeteria') {
          // Fetch stripeAccountId before deleting the Firestore doc
          final cafDoc = await _db
              .collection('cafeterias')
              .doc(user.userId)
              .get();
          final stripeAccountId = cafDoc.data()?['stripeAccountId'] as String?;

          // Delete Stripe Express account + Firebase Auth user via backend
          try {
            await http.post(
              Uri.parse('$_backendUrl/delete-cafeteria'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'uid': user.userId,
                'stripeAccountId': stripeAccountId,
              }),
            );
          } catch (_) {
            // Backend unavailable, continue with Firestore cleanup
          }

          batch.delete(_db.collection('cafeterias').doc(user.userId));

          // Delete all meals belonging to this cafeteria
          final mealsSnap = await _db
              .collection('meals')
              .where('cafeteriaId', isEqualTo: user.userId)
              .get();
          for (final doc in mealsSnap.docs) {
            batch.delete(doc.reference);
          }
        }

        _nonChildUsers.removeWhere((u) => u.userId == user.userId);
        users.removeWhere((u) => u.userId == user.userId);
        _applyFilter();
      }

      await batch.commit();
    } catch (_) {
    } finally {
      deletingIds.remove(user.userId);
    }
  }
}
