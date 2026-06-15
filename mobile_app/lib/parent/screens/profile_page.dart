import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.onBeforeSignOut});

  final VoidCallback? onBeforeSignOut;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _pink = Color(0xFFFF3366);
  static const _orange = Color(0xFFFF8C00);

  final _nameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _savingName = false;
  bool _savingPassword = false;
  bool _loading = true;
  bool _deletingAccount = false;

  static const _backendUrl = 'http://72.61.254.215:3000';

  String _email = '';
  String _schoolDisplayName = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = userDoc.data() ?? {};
      final schoolId = (data['schoolId'] as String?) ?? '';

      String schoolName = '';
      if (schoolId.isNotEmpty) {
        final schoolDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .get();
        schoolName =
            (schoolDoc.data()?['displayName'] as String?) ?? '';
      }

      if (mounted) {
        setState(() {
          _nameController.text = (data['name'] as String?) ?? '';
          _email = (data['email'] as String?) ?? '';
          _schoolDisplayName = schoolName;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveName() async {
    if (!(_nameFormKey.currentState?.validate() ?? false)) return;
    setState(() => _savingName = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final name = _nameController.text.trim();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'name': name});
      await FirebaseAuth.instance.currentUser!.updateDisplayName(name);
      if (mounted) {
        FocusScope.of(context).unfocus();
        _showSnack('Name updated successfully.', success: true);
      }
    } catch (_) {
      if (mounted) _showSnack('Failed to update name. Try again.');
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final passwordController = TextEditingController();
    bool obscure = true;
    String? dialogError;
    bool dialogLoading = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Delete Account',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will permanently delete your account, all your children\'s records, and your saved payment method. This cannot be undone.',
                style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9B9B9B),
                    height: 1.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Enter your password to confirm',
                  labelStyle: const TextStyle(
                      fontSize: 13, color: Color(0xFF9B9B9B)),
                  errorText: dialogError,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () =>
                        setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: dialogLoading
                  ? null
                  : () => Navigator.pop(ctx, false),
              child: const Text('CANCEL',
                  style: TextStyle(color: Color(0xFF9B9B9B))),
            ),
            TextButton(
              onPressed: dialogLoading
                  ? null
                  : () async {
                      final pwd = passwordController.text;
                      if (pwd.isEmpty) {
                        setDialogState(() =>
                            dialogError = 'Password is required');
                        return;
                      }
                      setDialogState(() {
                        dialogLoading = true;
                        dialogError = null;
                      });
                      try {
                        final user =
                            FirebaseAuth.instance.currentUser!;
                        final credential =
                            EmailAuthProvider.credential(
                          email: user.email!,
                          password: pwd,
                        );
                        await user.reauthenticateWithCredential(
                            credential);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } on FirebaseAuthException {
                        setDialogState(() {
                          dialogLoading = false;
                          dialogError = 'Incorrect password.';
                        });
                      }
                    },
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE53935)),
              child: dialogLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFE53935)),
                      ),
                    )
                  : const Text('DELETE',
                      style: TextStyle(
                          fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    passwordController.dispose();
    if (confirmed == true && mounted) _deleteAccount();
  }

  Future<void> _deleteAccount() async {
    setState(() => _deletingAccount = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final db = FirebaseFirestore.instance;

      // 1. Delete Stripe Customer if one exists
      final parentDoc = await db.collection('parents').doc(uid).get();
      final stripeCustomerId =
          parentDoc.data()?['stripeCustomerId'] as String?;
      if (stripeCustomerId != null) {
        await http.post(
          Uri.parse('$_backendUrl/delete-customer'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'customerId': stripeCustomerId}),
        );
      }

      // 2. Delete all children belonging to this parent
      final childrenSnap = await db
          .collection('children')
          .where('parentId', isEqualTo: uid)
          .get();
      final batch = db.batch();
      for (final doc in childrenSnap.docs) {
        batch.delete(doc.reference);
      }

      // 3. Delete parent and user documents
      batch.delete(db.collection('parents').doc(uid));
      batch.delete(db.collection('users').doc(uid));
      await batch.commit();

      // 4. Delete Firebase Auth account
      widget.onBeforeSignOut?.call();
      await FirebaseAuth.instance.currentUser!.delete();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context, '/type-selection', (_) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showSnack(e.code == 'requires-recent-login'
            ? 'Please sign out and sign back in, then try again.'
            : 'Failed to delete account. Try again.');
      }
    } catch (_) {
      if (mounted) _showSnack('Failed to delete account. Try again.');
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  Future<void> _changePassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
    setState(() => _savingPassword = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPasswordController.text);
      widget.onBeforeSignOut?.call();
      await AuthService.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context, '/type-selection', (_) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showSnack(
          e.code == 'wrong-password' || e.code == 'invalid-credential'
              ? 'Current password is incorrect.'
              : e.code == 'weak-password'
                  ? 'Password must be at least 6 characters.'
                  : 'Failed to change password. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            success ? const Color(0xFF43A047) : const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_pink),
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionCard(
                        title: 'Account Details',
                        child: _buildDetailsSection(),
                      ),
                      const SizedBox(height: 24),
                      _buildSectionCard(
                        title: 'Change Password',
                        child: _buildPasswordSection(),
                      ),
                      const SizedBox(height: 32),
                      _buildDeleteSection(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                size: 20, color: Color(0xFF1A1A1A)),
            onPressed: () => Navigator.pop(context),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PROFILE',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Manage your account',
                style: TextStyle(fontSize: 11, color: Color(0xFF9B9B9B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF9B9B9B),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return Form(
      key: _nameFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _readOnlyField(label: 'Email', value: _email),
          const SizedBox(height: 16),
          _readOnlyField(label: 'School', value: _schoolDisplayName),
          const SizedBox(height: 16),
          _editableField(
            controller: _nameController,
            label: 'Full Name',
            validator: (v) =>
                (v?.trim().isEmpty ?? true) ? 'Name cannot be empty' : null,
          ),
          const SizedBox(height: 20),
          _gradientButton(
            label: 'SAVE NAME',
            loading: _savingName,
            onPressed: _saveName,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _passwordField(
            controller: _currentPasswordController,
            label: 'Current Password',
            obscure: _obscureCurrent,
            onToggle: () =>
                setState(() => _obscureCurrent = !_obscureCurrent),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Enter your current password' : null,
          ),
          const SizedBox(height: 16),
          _passwordField(
            controller: _newPasswordController,
            label: 'New Password',
            obscure: _obscureNew,
            onToggle: () => setState(() => _obscureNew = !_obscureNew),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter a new password';
              if (v.length < 6) return 'At least 6 characters required';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _passwordField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            obscure: _obscureConfirm,
            onToggle: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
            validator: (v) => v != _newPasswordController.text
                ? 'Passwords do not match'
                : null,
          ),
          const SizedBox(height: 8),
          const Text(
            'You will be signed out after changing your password.',
            style: TextStyle(fontSize: 12, color: Color(0xFF9B9B9B)),
          ),
          const SizedBox(height: 20),
          _gradientButton(
            label: 'CHANGE PASSWORD',
            loading: _savingPassword,
            onPressed: _changePassword,
          ),
        ],
      ),
    );
  }

  Widget _readOnlyField({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF9B9B9B),
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value.isNotEmpty ? value : '—',
            style: const TextStyle(
                fontSize: 14, color: Color(0xFF9B9B9B)),
          ),
        ),
      ],
    );
  }

  Widget _editableField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF9B9B9B),
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
          decoration: _fieldDecoration(),
          validator: validator,
        ),
      ],
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF9B9B9B),
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
          decoration: _fieldDecoration(
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: const Color(0xFF9B9B9B),
              ),
              onPressed: onToggle,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({Widget? suffixIcon}) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      suffixIcon: suffixIcon,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _pink, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935))),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFE53935), width: 1.5)),
    );
  }

  Widget _buildDeleteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DANGER ZONE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE53935),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFCDD2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delete Account',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Permanently removes your account, children\'s records, and saved payment method.',
                style: TextStyle(fontSize: 12, color: Color(0xFF9B9B9B)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed:
                      _deletingAccount ? null : _confirmDeleteAccount,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE53935),
                    side: const BorderSide(color: Color(0xFFE53935)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(27)),
                  ),
                  child: _deletingAccount
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFE53935)),
                          ),
                        )
                      : const Text(
                          'DELETE ACCOUNT',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gradientButton({
    required String label,
    required bool loading,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_pink, _orange]),
          borderRadius: BorderRadius.circular(27),
        ),
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(27)),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
        ),
      ),
    );
  }
}
