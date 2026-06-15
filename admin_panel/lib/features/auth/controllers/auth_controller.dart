import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';

class AuthController extends GetxController {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  final isLoading = false.obs;
  final errorMessage = ''.obs;

  // Set after login/signup, used by all controllers to filter data.
  final schoolId = ''.obs;
  final schoolDisplayName = ''.obs;

  Future<void> loadSchoolInfo() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await _db.collection('admins').doc(user.uid).get();
      if (!doc.exists) return;
      final sid = (doc.data()?['schoolId'] as String?) ?? '';
      schoolId.value = sid;
      if (sid.isNotEmpty) {
        final schoolDoc = await _db.collection('schools').doc(sid).get();
        schoolDisplayName.value =
            (schoolDoc.data()?['displayName'] as String?) ?? '';
      }
    } catch (_) {}
  }

  Future<void> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      errorMessage.value = 'Please fill in all fields.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = '';
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await loadSchoolInfo();
      Get.offAllNamed(AppRoutes.HOME);
    } on FirebaseAuthException catch (e) {
      errorMessage.value = _mapAuthError(e.code);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signup(
    String email,
    String password,
    String schoolName,
    String branch,
  ) async {
    if (email.isEmpty || password.isEmpty || schoolName.isEmpty || branch.isEmpty) {
      errorMessage.value = 'All fields are required.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;
      final displayName = branch.trim().isNotEmpty
          ? '${schoolName.trim()} — ${branch.trim()}'
          : schoolName.trim();

      // Create school document (schoolId == admin uid for simplicity)
      await _db.collection('schools').doc(uid).set({
        'schoolId': uid,
        'name': schoolName.trim(),
        'branch': branch.trim(),
        'displayName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create admin document
      await _db.collection('admins').doc(uid).set({
        'adminId': uid,
        'userId': uid,
        'schoolId': uid,
        'role': 'school_admin',
      });

      // Create user document
      await _db.collection('users').doc(uid).set({
        'userId': uid,
        'email': email,
        'name': displayName,
        'role': 'admin',
        'timestamp': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });

      schoolId.value = uid;
      schoolDisplayName.value = displayName;

      Get.offAllNamed(AppRoutes.HOME);
    } on FirebaseAuthException catch (e) {
      errorMessage.value = _mapAuthError(e.code);
    } finally {
      isLoading.value = false;
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    if (email.isEmpty) return 'Please enter your email address first.';
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e.code);
    }
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser!;
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e.code);
    }
  }

  Future<void> logout() async {
    schoolId.value = '';
    schoolDisplayName.value = '';
    await _auth.signOut();
    Get.offAllNamed(AppRoutes.LOGIN);
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return 'Incorrect email or password.';
    }
  }
}
