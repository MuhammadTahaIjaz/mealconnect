import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  Future<void> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      errorMessage.value = 'Please fill in all fields.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = '';
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      Get.offAllNamed(AppRoutes.HOME);
    } on FirebaseAuthException catch (e) {
      errorMessage.value = _mapAuthError(e.code);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signup(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      errorMessage.value = 'Please fill in all fields.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = '';
    try {
      await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      Get.offAllNamed(AppRoutes.HOME);
    } on FirebaseAuthException catch (e) {
      errorMessage.value = _mapAuthError(e.code);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
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
