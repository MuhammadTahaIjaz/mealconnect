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
  final _emailController      = TextEditingController();
  final _passwordController   = TextEditingController();
  final _schoolNameController = TextEditingController();
  final _branchController     = TextEditingController();

  final _passwordFocus   = FocusNode();
  final _schoolNameFocus = FocusNode();
  final _branchFocus     = FocusNode();

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
    _schoolNameController.dispose();
    _branchController.dispose();
    _passwordFocus.dispose();
    _schoolNameFocus.dispose();
    _branchFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (_auth.isLoading.value) return;
    final email    = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (_isSignUp.value) {
      _auth.signup(
        email,
        password,
        _schoolNameController.text.trim(),
        _branchController.text.trim(),
      );
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
                      _isSignUp.value ? 'Create School Account' : 'Admin Panel',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    )),
                const SizedBox(height: 36),

                // ── Email ────────────────────────────────────────────────────
                _buildLabel('Email'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _emailController,
                  hint: 'admin@school.com',
                  icon: Icons.email_outlined,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_passwordFocus),
                ),
                const SizedBox(height: 20),

                // ── Password ─────────────────────────────────────────────────
                _buildLabel('Password'),
                const SizedBox(height: 6),
                Obx(() => _buildTextField(
                      controller: _passwordController,
                      hint: '••••••••',
                      icon: Icons.lock_outline,
                      obscure: true,
                      focusNode: _passwordFocus,
                      textInputAction: _isSignUp.value
                          ? TextInputAction.next
                          : TextInputAction.done,
                      onSubmitted: _isSignUp.value
                          ? (_) => FocusScope.of(context)
                              .requestFocus(_schoolNameFocus)
                          : (_) => _submit(),
                    )),

                // ── Forgot password (login mode only) ────────────────────────
                Obx(() => !_isSignUp.value
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () async {
                            final err = await _auth.sendPasswordReset(
                                _emailController.text.trim());
                            if (err != null) {
                              _auth.errorMessage.value = err;
                            } else {
                              _auth.errorMessage.value = '';
                              Get.snackbar(
                                'Email Sent',
                                'Password reset link sent. Check your inbox.',
                                snackPosition: SnackPosition.BOTTOM,
                                backgroundColor: AppColors.success,
                                colorText: Colors.white,
                                margin: const EdgeInsets.all(16),
                              );
                            }
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: AppColors.primaryPink,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink()),

                // ── Sign-up only: School Name + Branch ────────────────────────
                Obx(() => _isSignUp.value
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 20),
                          _buildLabel('School Name'),
                          const SizedBox(height: 6),
                          _buildTextField(
                            controller: _schoolNameController,
                            hint: 'e.g. Beacon House',
                            icon: Icons.school_outlined,
                            focusNode: _schoolNameFocus,
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) =>
                                FocusScope.of(context).requestFocus(_branchFocus),
                          ),
                          const SizedBox(height: 20),
                          _buildLabel('Branch / City Name'),
                          const SizedBox(height: 6),
                          _buildTextField(
                            controller: _branchController,
                            hint: 'e.g. Gulshan Campus or Lahore',
                            icon: Icons.location_on_outlined,
                            focusNode: _branchFocus,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'If your school has only one branch, enter the city name. '
                            'For multiple branches, use the branch name.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink()),

                const SizedBox(height: 24),

                // ── Error ─────────────────────────────────────────────────────
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

                // ── Submit button ─────────────────────────────────────────────
                Obx(() => _buildGradientButton(
                      label: _auth.isLoading.value
                          ? 'Please wait...'
                          : (_isSignUp.value ? 'Create Account' : 'Sign In'),
                      onTap: _auth.isLoading.value ? null : _submit,
                    )),

                const SizedBox(height: 20),

                // ── Toggle login / signup ─────────────────────────────────────
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
