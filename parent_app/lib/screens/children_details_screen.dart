import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChildrenDetailsScreen extends StatefulWidget {
  const ChildrenDetailsScreen({super.key});

  @override
  State<ChildrenDetailsScreen> createState() => _ChildrenDetailsScreenState();
}

class _ChildrenDetailsScreenState extends State<ChildrenDetailsScreen> {
  static const _pink = Color(0xFFFF3366);
  static const _orange = Color(0xFFFF8C00);

  final _formKey = GlobalKey<FormState>();
  final _sharedSchoolController = TextEditingController();

  int _childCount = 1;
  bool _sameSchool = true;
  bool _isLoading = false;
  String? _errorMessage;

  final List<TextEditingController> _nameControllers = [];
  final List<TextEditingController> _idControllers = [];
  final List<TextEditingController> _schoolControllers = [];

  @override
  void initState() {
    super.initState();
    _addControllers();
  }

  @override
  void dispose() {
    _sharedSchoolController.dispose();
    for (final c in [
      ..._nameControllers,
      ..._idControllers,
      ..._schoolControllers,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addControllers() {
    _nameControllers.add(TextEditingController());
    _idControllers.add(TextEditingController());
    _schoolControllers.add(TextEditingController());
  }

  void _removeControllers() {
    _nameControllers.last.dispose();
    _nameControllers.removeLast();
    _idControllers.last.dispose();
    _idControllers.removeLast();
    _schoolControllers.last.dispose();
    _schoolControllers.removeLast();
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
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      for (int i = 0; i < _childCount; i++) {
        final ref = firestore.collection('children').doc();
        batch.set(ref, {
          'childId': ref.id,
          'parentId': uid,
          'name': _nameControllers[i].text.trim(),
          'classRollNo': _idControllers[i].text.trim(),
          'schoolName': _sameSchool
              ? _sharedSchoolController.text.trim()
              : _schoolControllers[i].text.trim(),
          'schoolId': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/parent-home');
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to save. Please check your connection and try again.';
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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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
                            letterSpacing: 2.0,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildCountRow(),
                      const SizedBox(height: 16),
                      _buildSameSchoolToggle(),
                      const SizedBox(height: 28),
                      ...List.generate(_childCount, _buildChildForm),
                      if (_sameSchool) ...[
                        const SizedBox(height: 4),
                        _buildField(
                          controller: _sharedSchoolController,
                          label: 'School / College Name',
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'School name is required';
                            }
                            return null;
                          },
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
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
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              _buildContinueButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
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
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Row(
              children: [
                _stepperBtn('-', () => _onCountChange(-1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    '$_childCount',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                _stepperBtn('+', () => _onCountChange(1)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepperBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            color: Color(0xFF9B9B9B),
          ),
        ),
      ),
    );
  }

  Widget _buildSameSchoolToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'All Children are in same School?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          const SizedBox(width: 12),
          _radioOption('No', !_sameSchool, () => setState(() => _sameSchool = false)),
          const SizedBox(width: 18),
          _radioOption('Yes', _sameSchool, () => setState(() => _sameSchool = true)),
        ],
      ),
    );
  }

  Widget _radioOption(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? _orange : Colors.transparent,
              border: Border.all(
                color: selected ? _orange : const Color(0xFFCCCCCC),
                width: 2,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? _orange : const Color(0xFF9B9B9B),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildForm(int index) {
    return Column(
      children: [
        Center(
          child: Container(
            width: 66,
            height: 66,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_pink, _orange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 14),
        _buildField(
          controller: _nameControllers[index],
          label: 'Children Name',
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Name is required' : null,
        ),
        const SizedBox(height: 12),
        _buildField(
          controller: _idControllers[index],
          label: 'Child School ID',
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'School ID is required' : null,
        ),
        if (!_sameSchool) ...[
          const SizedBox(height: 12),
          _buildField(
            controller: _schoolControllers[index],
            label: 'School / College Name',
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'School name is required' : null,
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
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
          color: Color(0xFF9B9B9B),
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _pink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      color: Colors.white,
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
                  gradient: const LinearGradient(colors: [_pink, _orange]),
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
}
