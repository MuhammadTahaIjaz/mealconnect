import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class EditChildScreen extends StatefulWidget {
  const EditChildScreen({super.key});

  @override
  State<EditChildScreen> createState() => _EditChildScreenState();
}

class _EditChildScreenState extends State<EditChildScreen> {
  static const _pink = Color(0xFFFF3366);
  static const _orange = Color(0xFFFF8C00);

  late final String _childId;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();

  bool _isLoading = false;
  bool _initialized = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)!.settings.arguments
        as Map<String, dynamic>;
    _childId = args['childId'] as String;
    final data = args['data'] as Map<String, dynamic>;

    _nameController.text = (data['name'] as String?) ?? '';
    _idController.text = (data['classRollNo'] as String?) ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      await db.collection('children').doc(_childId).update({
        'name': _nameController.text.trim(),
        'classRollNo': _idController.text.trim(),
        'verificationStatus': 'pending',
      });

      final adminUid = await AuthService.getSchoolAdminUidForCurrentParent();
      await db.collection('notifications').add({
        'userId': adminUid ?? 'admin',
        'title': 'Child Re-Verification Request',
        'message':
            '${_nameController.text.trim()} — profile updated, re-verification required.',
        'type': 'child_update_request',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to update. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Color(0xFF1A1A1A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'EDIT CHILD',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
            color: Color(0xFF1A1A1A),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [_pink, _orange],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(Icons.person,
                            color: Colors.white, size: 34),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Saving will reset verification to pending',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9B9B9B),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildShadowField(
                        controller: _nameController,
                        label: 'Child Name',
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Name is required'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _buildShadowField(
                        controller: _idController,
                        label: 'Child School ID',
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'School ID is required'
                            : null,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                                color: Color(0xFFE53935), fontSize: 13),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShadowField({
    required TextEditingController controller,
    required String label,
    FormFieldValidator<String>? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        validator: validator,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A1A1A),
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
              color: Color(0xFF9B9B9B), fontSize: 13),
          floatingLabelStyle: const TextStyle(
              color: Color(0xFF9B9B9B), fontSize: 12),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _pink, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE53935)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: Color(0xFFE53935), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_pink),
                ),
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_pink, _orange],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(27),
                ),
                child: ElevatedButton(
                  onPressed: _onSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                  child: const Text(
                    'SAVE CHANGES',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
