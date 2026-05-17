import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/theme/app_colors.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  final _isSignUp = false.obs;

  late final AuthController _auth;

  @override
  void initState() {
    super.initState();
    _auth = Get.find<AuthController>();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (_auth.isLoading.value) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (_isSignUp.value) {
      _auth.signup(email, password);
    } else {
      _auth.login(email, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.primaryGradient.createShader(bounds),
                  child: const Text(
                    'MealConnect',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Obx(() => Text(
                      _isSignUp.value ? 'Create Admin Account' : 'Admin Panel',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    )),
                const SizedBox(height: 36),

                _buildLabel('Email'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _emailController,
                  hint: 'admin@mealconnect.com',
                  icon: Icons.email_outlined,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_passwordFocus),
                ),
                const SizedBox(height: 20),

                _buildLabel('Password'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _passwordController,
                  hint: '••••••••',
                  icon: Icons.lock_outline,
                  obscure: true,
                  focusNode: _passwordFocus,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 12),

                Obx(() => _auth.errorMessage.value.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _auth.errorMessage.value,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: AppColors.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : const SizedBox.shrink()),

                Obx(() => _buildGradientButton(
                      label: _auth.isLoading.value
                          ? 'Please wait...'
                          : (_isSignUp.value ? 'Create Account' : 'Sign In'),
                      onTap: _auth.isLoading.value ? null : _submit,
                    )),

                const SizedBox(height: 20),

                Obx(() => GestureDetector(
                      onTap: () {
                        _isSignUp.value = !_isSignUp.value;
                        _auth.errorMessage.value = '';
                      },
                      child: Text(
                        _isSignUp.value
                            ? 'Already have an account? Sign In'
                            : "Don't have an account? Sign Up",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: AppColors.primaryPink,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    FocusNode? focusNode,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.primaryPink, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: onTap != null
              ? AppColors.primaryGradient
              : const LinearGradient(
                  colors: [Color(0xFFCCCCCC), Color(0xFFCCCCCC)]),
          borderRadius: BorderRadius.circular(25),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
