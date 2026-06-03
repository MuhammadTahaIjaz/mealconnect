import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../auth/controllers/auth_controller.dart';

class UserRecord {
  final String userId;
  final String name;
  final String email;
  final String role;
  final Timestamp? timestamp;
  final String? parentName; // children only
  final String? parentId;   // children only — used to cascade on parent delete

  UserRecord({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.timestamp,
    this.parentName,
    this.parentId,
  });
}

class UsersController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final users         = <UserRecord>[].obs;
  final filteredUsers = <UserRecord>[].obs;
  final isLoading     = true.obs;
  final selectedRole  = 'All'.obs;
  final searchQuery   = ''.obs;
  final deletingIds   = <String>[].obs;

  final roles = ['All', 'parent', 'cafeteria', 'child', 'admin'];

  @override
  void onInit() {
    super.onInit();
    fetchUsers();
    ever(selectedRole, (_) => _applyFilter());
    ever(searchQuery,  (_) => _applyFilter());
  }

  Future<void> fetchUsers() async {
    isLoading.value = true;
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final schoolId   = Get.find<AuthController>().schoolId.value;

      // ── Fetch users (parents, cafeterias, admins) ──────────────────────
      final usersSnap = await _db.collection('users').get();
      final userRecords = usersSnap.docs
          .where((doc) => doc.id != currentUid)
          .map((doc) {
            final d = doc.data();
            return UserRecord(
              userId:    doc.id,
              name:      d['name']  ?? '',
              email:     d['email'] ?? '',
              role:      d['role']  ?? '',
              timestamp: d['timestamp'],
            );
          }).toList();

      // Build a parentId → name lookup for children
      final parentNameMap = {for (final u in userRecords) u.userId: u.name};

      // ── Fetch children ──────────────────────────────────────────────────
      List<UserRecord> childRecords = [];
      if (schoolId.isNotEmpty) {
        final childrenSnap = await _db
            .collection('children')
            .where('schoolId', isEqualTo: schoolId)
            .get();
        childRecords = childrenSnap.docs.map((doc) {
          final d = doc.data();
          final pid = d['parentId'] as String? ?? '';
          return UserRecord(
            userId:     doc.id,
            name:       d['name'] ?? '',
            email:      '',
            role:       'child',
            timestamp:  d['createdAt'],
            parentName: parentNameMap[pid] ?? '',
            parentId:   pid,
          );
        }).toList();
      }

      users.value = [...userRecords, ...childRecords];
      _applyFilter();
    } catch (_) {
    } finally {
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
      list = list.where((u) =>
          u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          (u.parentName?.toLowerCase().contains(q) ?? false)).toList();
    }
    filteredUsers.value = list;
  }

  Future<void> deleteUser(UserRecord user) async {
    if (deletingIds.contains(user.userId)) return;
    deletingIds.add(user.userId);
    try {
      final batch = _db.batch();

      if (user.role == 'child') {
        // Children exist only in the children collection
        batch.delete(_db.collection('children').doc(user.userId));
      } else {
        // All other roles have a users doc
        batch.delete(_db.collection('users').doc(user.userId));

        if (user.role == 'parent') {
          batch.delete(_db.collection('parents').doc(user.userId));
          // Cascade: delete all children of this parent
          final childrenSnap = await _db
              .collection('children')
              .where('parentId', isEqualTo: user.userId)
              .get();
          for (final doc in childrenSnap.docs) {
            batch.delete(doc.reference);
          }
          // Remove those children from local list too
          users.removeWhere(
              (u) => u.role == 'child' && u.parentId == user.userId);
        } else if (user.role == 'cafeteria') {
          batch.delete(_db.collection('cafeterias').doc(user.userId));
        }
      }

      await batch.commit();
      users.removeWhere((u) => u.userId == user.userId);
      _applyFilter();
    } catch (_) {
    } finally {
      deletingIds.remove(user.userId);
    }
  }
}
