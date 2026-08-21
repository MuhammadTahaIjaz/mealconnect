import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class ChildrenDetailsScreen extends StatefulWidget {
  const ChildrenDetailsScreen({super.key});

  @override
  State<ChildrenDetailsScreen> createState() => _ChildrenDetailsScreenState();
}

class _ChildrenDetailsScreenState extends State<ChildrenDetailsScreen> {
  static const _pink = Color(0xFFFF3366);
  static const _orange = Color(0xFFFF8C00);

  static const _classOptions = [
    'Play Group', 'Nursery', 'Prep',
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10',
  ];

  final _formKey = GlobalKey<FormState>();

  int _childCount = 1;
  bool _isLoading = false;
  String? _errorMessage;

  final List<TextEditingController> _nameControllers = [];
  final List<String?> _classLevels = [];
  final List<TextEditingController> _sectionControllers = [];
  final List<TextEditingController> _rollControllers = [];

  @override
  void initState() {
    super.initState();
    _addControllers();
  }

  @override
  void dispose() {
    for (final c in [
      ..._nameControllers,
      ..._sectionControllers,
      ..._rollControllers,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addControllers() {
    _nameControllers.add(TextEditingController());
    _classLevels.add(null);
    _sectionControllers.add(TextEditingController());
    _rollControllers.add(TextEditingController());
  }

  void _removeControllers() {
    _nameControllers.last.dispose();
    _nameControllers.removeLast();
    _classLevels.removeLast();
    _sectionControllers.last.dispose();
    _sectionControllers.removeLast();
    _rollControllers.last.dispose();
    _rollControllers.removeLast();
  }

  void _onCountChange(int delta) {
    final next = (_childCount + delta).clamp(1, 5);
    if (next == _childCount) return;
    setState(() {
      next > _childCount ? _addControllers() : _removeControllers();
      _childCount = next;
    });
  }

  Future<void> _onContinue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final db = FirebaseFirestore.instance;

      final schoolId = await AuthService.getCurrentParentSchoolId();
      String schoolName = '';
      if (schoolId.isNotEmpty) {
        final schoolDoc = await db.collection('schools').doc(schoolId).get();
        schoolName = (schoolDoc.data()?['displayName'] as String?) ?? '';
      }

      final batch = db.batch();
      for (int i = 0; i < _childCount; i++) {
        final ref = db.collection('children').doc();
        batch.set(ref, {
          'childId': ref.id,
          'parentId': uid,
          'schoolId': schoolId,
          'schoolName': schoolName,
          'name': _nameControllers[i].text.trim(),
          'classLevel': _classLevels[i],
          'section': _sectionControllers[i].text.trim(),
          'rollNumber': _rollControllers[i].text.trim(),
          'verificationStatus': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      final childNames = List.generate(
        _childCount,
        (i) => _nameControllers[i].text.trim(),
      ).join(', ');
      final adminUid = await AuthService.getSchoolAdminUidForCurrentParent();
      await db.collection('notifications').add({
        'userId': adminUid ?? 'admin',
        'title': 'New Child Verification Request',
        'message': '$childNames, verification required.',
        'type': 'new_child_request',
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        final status = await AuthService.getAccountStatus(uid);
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          status == 'approved' ? '/parent-home' : '/parent-pending',
        );
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Failed to save. Please check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 36),
                      const Center(
                        child: Text(
                          'CHILDREN DETAILS',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildCountCard(),
                      const SizedBox(height: 24),
                      ...List.generate(_childCount, _buildChildForm),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
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
                              color: Color(0xFFE53935),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              _buildContinueButton(),
              _buildSkipButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'No. of Children',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFDDDDDD), width: 1),
            ),
            child: Row(
              children: [
                _stepperBtn('-', () => _onCountChange(-1)),
                Container(
                    width: 1, height: 28, color: const Color(0xFFEEEEEE)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    '$_childCount',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                Container(
                    width: 1, height: 28, color: const Color(0xFFEEEEEE)),
                _stepperBtn('+', () => _onCountChange(1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepperBtn(String symbol, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Text(
            symbol,
            style: const TextStyle(
              fontSize: 20,
              color: Color(0xFF9B9B9B),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChildForm(int index) {
    return Column(
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_pink, _orange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _nameControllers[index],
          label: 'Child Name',
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Name is required' : null,
        ),
        const SizedBox(height: 12),
        _buildDropdown(
          label: 'Class',
          value: _classLevels[index],
          options: _classOptions,
          onChanged: (v) => setState(() => _classLevels[index] = v),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _sectionControllers[index],
          label: 'Section',
          hint: 'e.g. A, B, Blue, Green',
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Section is required' : null,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _rollControllers[index],
          label: 'Roll Number',
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Roll number is required' : null,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
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
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A1A1A),
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle:
              const TextStyle(color: Color(0xFFCCCCCC), fontSize: 13),
          labelStyle: const TextStyle(
            color: Color(0xFF9B9B9B),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          floatingLabelStyle:
              const TextStyle(color: Color(0xFF9B9B9B), fontSize: 12),
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

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required void Function(String?) onChanged,
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
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              const TextStyle(color: Color(0xFF9B9B9B), fontSize: 13),
          floatingLabelStyle:
              const TextStyle(color: Color(0xFF9B9B9B), fontSize: 12),
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
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: onChanged,
        validator: (v) => v == null ? 'Class is required' : null,
        borderRadius: BorderRadius.circular(14),
        dropdownColor: Colors.white,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A1A1A),
        ),
        icon: const Icon(Icons.keyboard_arrow_down,
            color: Color(0xFF9B9B9B)),
      ),
    );
  }

  Widget _buildContinueButton() {
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
                  onPressed: _onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                  child: const Text(
                    'CONTINUE',
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

  Widget _buildSkipButton() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () async {
          final uid = FirebaseAuth.instance.currentUser!.uid;
          final status = await AuthService.getAccountStatus(uid);
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            status == 'approved' ? '/parent-home' : '/parent-pending',
          );
        },
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Skip for now',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF9B9B9B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
