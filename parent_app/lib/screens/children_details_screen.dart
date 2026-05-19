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
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      for (int i = 0; i < _childCount; i++) {
        final ref = db.collection('children').doc();
        batch.set(ref, {
          'childId': ref.id,
          'parentId': uid,
          'name': _nameControllers[i].text.trim(),
          'classRollNo': _idControllers[i].text.trim(),
          'schoolName': _sameSchool
              ? _sharedSchoolController.text.trim()
              : _schoolControllers[i].text.trim(),
          'schoolId': '',
          'verificationStatus': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

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

                      // ── Title ───────────────────────────────────────────
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

                      // ── No. of Children ──────────────────────────────────
                      _buildCountCard(),
                      const SizedBox(height: 16),

                      // ── Same School Toggle ────────────────────────────────
                      _buildSameSchoolRow(),
                      const SizedBox(height: 24),

                      // ── Child Forms ──────────────────────────────────────
                      ...List.generate(_childCount, _buildChildForm),

                      // ── Shared school name ────────────────────────────────
                      if (_sameSchool) ...[
                        _buildShadowField(
                          controller: _sharedSchoolController,
                          label: 'School / Collage Name',
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'School name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                      ],

                      // ── Error ─────────────────────────────────────────────
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

              // ── Fixed CONTINUE button ─────────────────────────────────────
              _buildContinueButton(),
              _buildSkipButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ── No. of Children card ─────────────────────────────────────────────────

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
          // Stepper pill: "- 2 +"
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFDDDDDD), width: 1),
            ),
            child: Row(
              children: [
                _stepperBtn('-', () => _onCountChange(-1)),
                Container(
                  width: 1,
                  height: 28,
                  color: const Color(0xFFEEEEEE),
                ),
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
                  width: 1,
                  height: 28,
                  color: const Color(0xFFEEEEEE),
                ),
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

  // ── Same School row ───────────────────────────────────────────────────────

  Widget _buildSameSchoolRow() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'All Children are in same School?',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // "No" option
        GestureDetector(
          onTap: () => setState(() => _sameSchool = false),
          child: Column(
            children: [
              _radioCircle(selected: !_sameSchool),
              const SizedBox(height: 3),
              Text(
                'No',
                style: TextStyle(
                  fontSize: 12,
                  color: !_sameSchool ? _orange : const Color(0xFF9B9B9B),
                  fontWeight:
                      !_sameSchool ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // "Yes" option
        GestureDetector(
          onTap: () => setState(() => _sameSchool = true),
          child: Column(
            children: [
              _radioCircle(selected: _sameSchool),
              const SizedBox(height: 3),
              Text(
                'Yes',
                style: TextStyle(
                  fontSize: 12,
                  color: _sameSchool ? _orange : const Color(0xFF9B9B9B),
                  fontWeight:
                      _sameSchool ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _radioCircle({required bool selected}) {
    return AnimatedContainer(
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
    );
  }

  // ── Child form block ──────────────────────────────────────────────────────

  Widget _buildChildForm(int index) {
    return Column(
      children: [
        // Centered avatar
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

        // Name field
        _buildShadowField(
          controller: _nameControllers[index],
          label: 'Children Name',
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Name is required' : null,
        ),
        const SizedBox(height: 12),

        // School ID field
        _buildShadowField(
          controller: _idControllers[index],
          label: 'Child School ID',
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'School ID is required' : null,
        ),

        // Per-child school name (when different schools)
        if (!_sameSchool) ...[
          const SizedBox(height: 12),
          _buildShadowField(
            controller: _schoolControllers[index],
            label: 'School / Collage Name',
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'School name is required' : null,
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Shadow text field (matches design: shadow instead of outline) ─────────

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
          fontSize: 16,
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
          floatingLabelStyle: const TextStyle(
            color: Color(0xFF9B9B9B),
            fontSize: 12,
          ),
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

  // ── Continue button fixed at bottom ───────────────────────────────────────

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
