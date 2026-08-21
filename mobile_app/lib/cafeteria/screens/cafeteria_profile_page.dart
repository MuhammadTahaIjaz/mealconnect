import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class CafeteriaProfilePage extends StatefulWidget {
  const CafeteriaProfilePage({super.key, this.onBeforeSignOut});

  final VoidCallback? onBeforeSignOut;

  @override
  State<CafeteriaProfilePage> createState() => _CafeteriaProfilePageState();
}

class _CafeteriaProfilePageState extends State<CafeteriaProfilePage> {
  static const _pink = Color(0xFFFF3366);
  static const _orange = Color(0xFFFF8C00);
  static const _backendUrl = 'http://72.61.254.215:3000';

  final _nameController = TextEditingController();
  final _cafeteriaNameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrent = true;
  final _detailsFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _savingDetails = false;
  bool _savingPassword = false;
  bool _loading = true;
  bool _deletingAccount = false;

  String _email = '';
  String _schoolDisplayName = '';
  String _schoolId = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cafeteriaNameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
        FirebaseFirestore.instance.collection('cafeterias').doc(uid).get(),
      ]);

      final userData = results[0].data() ?? {};
      final cafeteriaData = results[1].data() ?? {};
      final schoolId = (userData['schoolId'] as String?) ?? '';

      String schoolName = '';
      if (schoolId.isNotEmpty) {
        final schoolDoc = await FirebaseFirestore.instance
            .collection('schools')
            .doc(schoolId)
            .get();
        schoolName = (schoolDoc.data()?['displayName'] as String?) ?? '';
      }

      if (mounted) {
        setState(() {
          _nameController.text = (userData['name'] as String?) ?? '';
          _cafeteriaNameController.text =
              (cafeteriaData['cafeteriaName'] as String?) ?? '';
          _email = (userData['email'] as String?) ?? '';
          _schoolDisplayName = schoolName;
          _schoolId = schoolId;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveChanges() async {
    if (!(_detailsFormKey.currentState?.validate() ?? false)) return;
    setState(() => _savingDetails = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final db = FirebaseFirestore.instance;
      final name = _nameController.text.trim();
      final cafName = _cafeteriaNameController.text.trim();

      final batch = db.batch();
      batch.update(db.collection('users').doc(uid), {'name': name});
      batch.update(db.collection('cafeterias').doc(uid), {
        'cafeteriaName': cafName,
        'accountStatus': 'pending',
        'isVerified': false,
      });
      await batch.commit();
      await FirebaseAuth.instance.currentUser!.updateDisplayName(name);

      // Notify school admin for re-verification
      if (_schoolId.isNotEmpty) {
        final adminSnap = await db
            .collection('admins')
            .where('schoolId', isEqualTo: _schoolId)
            .limit(1)
            .get();
        if (adminSnap.docs.isNotEmpty) {
          final adminUid =
              adminSnap.docs.first.data()['userId'] as String?;
          if (adminUid != null) {
            await db.collection('notifications').add({
              'userId': adminUid,
              'title': 'Cafeteria Profile Updated',
              'message':
                  '$cafName has updated their profile and is awaiting re-verification.',
              'type': 'new_cafeteria_request',
              'isRead': false,
              'timestamp': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context, '/cafeteria-pending', (_) => false);
      }
    } catch (_) {
      if (mounted) _showSnack('Failed to save changes. Try again.');
    } finally {
      if (mounted) setState(() => _savingDetails = false);
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
                fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will permanently delete your cafeteria account and all associated data. This cannot be undone.',
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
                      style: TextStyle(fontWeight: FontWeight.w700)),
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
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final db = FirebaseFirestore.instance;

      widget.onBeforeSignOut?.call();

      final cafDoc = await db.collection('cafeterias').doc(uid).get();
      final stripeAccountId =
          cafDoc.data()?['stripeAccountId'] as String?;

      await http.post(
        Uri.parse('$_backendUrl/delete-cafeteria'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid, 'stripeAccountId': stripeAccountId}),
      );

      final batch = db.batch();
      batch.delete(db.collection('cafeterias').doc(uid));
      batch.delete(db.collection('users').doc(uid));
      await batch.commit();

      final meals = await db
          .collection('meals')
          .where('cafeteriaId', isEqualTo: uid)
          .get();
      if (meals.docs.isNotEmpty) {
        final mealBatch = db.batch();
        for (final doc in meals.docs) mealBatch.delete(doc.reference);
        await mealBatch.commit();
      }

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context, '/type-selection', (_) => false);
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
      key: _detailsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _readOnlyField(label: 'Email', value: _email),
          const SizedBox(height: 16),
          _readOnlyField(label: 'School', value: _schoolDisplayName),
          const SizedBox(height: 16),
          _editableField(
            controller: _cafeteriaNameController,
            label: 'Cafeteria Name',
            validator: (v) => (v?.trim().isEmpty ?? true)
                ? 'Cafeteria name cannot be empty'
                : null,
          ),
          const SizedBox(height: 16),
          _editableField(
            controller: _nameController,
            label: 'Owner Name',
            validator: (v) =>
                (v?.trim().isEmpty ?? true) ? 'Owner name cannot be empty' : null,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFF5A623).withValues(alpha: 0.45)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFFF5A623), size: 18),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Saving changes will pause your account for re-approval. '
                    'You will not be able to use the app until the school admin '
                    'reviews and approves your updated profile.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8B6900),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _gradientButton(
            label: 'SAVE CHANGES',
            loading: _savingDetails,
            onPressed: _saveChanges,
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
                'Permanently removes your cafeteria account and all associated data.',
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
