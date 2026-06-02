import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class UserRecord {
  final String userId;
  final String name;
  final String email;
  final String role;
  final Timestamp? timestamp;

  UserRecord({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.timestamp,
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

  final roles = ['All', 'parent', 'cafeteria', 'admin'];

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
      final snapshot = await _db.collection('users').get();
      users.value = snapshot.docs
          .where((doc) => doc.id != currentUid)
          .map((doc) {
        final data = doc.data();
        return UserRecord(
          userId:    doc.id,
          name:      data['name']  ?? '',
          email:     data['email'] ?? '',
          role:      data['role']  ?? '',
          timestamp: data['timestamp'],
        );
      }).toList();
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
      list = list
          .where((u) =>
              u.name.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q))
          .toList();
    }
    filteredUsers.value = list;
  }

  Future<void> deleteUser(UserRecord user) async {
    if (deletingIds.contains(user.userId)) return;
    deletingIds.add(user.userId);
    try {
      final batch = _db.batch();

      // Always remove from users collection
      batch.delete(_db.collection('users').doc(user.userId));

      if (user.role == 'parent') {
        // Remove from parents collection
        batch.delete(_db.collection('parents').doc(user.userId));
        // Cascade: remove all children of this parent
        final childrenSnap = await _db
            .collection('children')
            .where('parentId', isEqualTo: user.userId)
            .get();
        for (final doc in childrenSnap.docs) {
          batch.delete(doc.reference);
        }
      } else if (user.role == 'cafeteria') {
        // Remove from cafeterias collection
        batch.delete(_db.collection('cafeterias').doc(user.userId));
      }

      await batch.commit();

      // Remove from local lists immediately
      users.removeWhere((u) => u.userId == user.userId);
      _applyFilter();
    } catch (_) {
      // Silently keep the user in the list if deletion fails
    } finally {
      deletingIds.remove(user.userId);
    }
  }
}
