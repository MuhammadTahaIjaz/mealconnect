import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      try {
        final doc = await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .get()
            .timeout(const Duration(seconds: 10));

        if (!doc.exists || doc.data()?['role'] != 'cafeteria') {
          await _auth.signOut();
          return 'This account is not registered as a cafeteria.';
        }
      } catch (_) {
        await _auth.signOut();
        return 'Unable to verify your account. Check your internet connection and try again.';
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    }
  }

  static Future<String?> signUp({
    required String name,
    required String cafeteriaName,
    required String email,
    required String password,
    required String schoolId,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;
      await credential.user!.updateDisplayName(name);

      await _firestore.collection('users').doc(uid).set({
        'userId': uid,
        'name': name,
        'email': email,
        'role': 'cafeteria',
        'schoolId': schoolId,
        'timestamp': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('cafeterias').doc(uid).set({
        'cafeteriaId': uid,
        'userId': uid,
        'cafeteriaName': cafeteriaName,
        'schoolId': schoolId,
        'isVerified': false,
      });

      // Notify the school's admin
      final adminUid = await _getSchoolAdminUid(schoolId);
      await _firestore.collection('notifications').add({
        'userId': adminUid ?? 'admin',
        'title': 'New Cafeteria Registration',
        'message': '$cafeteriaName has registered and is awaiting verification.',
        'type': 'new_cafeteria_request',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return null;
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    }
  }

  static Future<String?> _getSchoolAdminUid(String schoolId) async {
    if (schoolId.isEmpty) return null;
    try {
      final snap = await _firestore
          .collection('admins')
          .where('schoolId', isEqualTo: schoolId)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 8));
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data()['userId'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> signOut() => _auth.signOut();

  static String _errorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
