import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AddMealScreen extends StatefulWidget {
  const AddMealScreen({super.key});

  @override
  State<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends State<AddMealScreen> {
  static const _pink = Color(0xFFFF3366);
  static const _orange = Color(0xFFFF8C00);

  static const _days = [
    'Monday', 'Tuesday', 'Wednesday',
    'Thursday', 'Friday', 'Saturday',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  final Set<String> _selectedDays = {'Monday'};
  bool _daysError = false;

  File? _imageFile;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 800,
    );
    if (picked != null && mounted) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _onSubmit() async {
    final daysValid = _selectedDays.isNotEmpty;
    setState(() => _daysError = !daysValid);
    if (!_formKey.currentState!.validate() || !daysValid) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final db = FirebaseFirestore.instance;
      final ref = db.collection('meals').doc();

      final cafDoc = await db.collection('cafeterias').doc(uid).get();
      final schoolId = (cafDoc.data()?['schoolId'] as String?) ?? '';

      String imageUrl = '';
      if (_imageFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('meals/$uid/${ref.id}.jpg');
        await storageRef.putFile(_imageFile!);
        imageUrl = await storageRef.getDownloadURL();
      }

      await ref.set({
        'mealId': ref.id,
        'cafeteriaId': uid,
        'schoolId': schoolId,
        'mealName': _nameController.text.trim(),
        'availability': _selectedDays.toList(),
        'price': double.tryParse(_priceController.text.trim()) ?? 0.0,
        'isAvailable': true,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to save meal. Please try again.';
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
          'ENTER DETAILS',
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Meal Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildShadowField(
                        controller: _nameController,
                        label: 'Meal Name',
                        hint: 'e.g. Pizza',
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Meal name is required'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _buildDaySelector(),
                      const SizedBox(height: 14),
                      _buildShadowField(
                        controller: _priceController,
                        label: 'Price',
                        hint: 'e.g. 40',
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Price is required';
                          }
                          final parsed = double.tryParse(v.trim());
                          if (parsed == null) {
                            return 'Enter a valid number';
                          }
                          if (parsed > 100000) {
                            return 'Price cannot exceed Rs. 100,000';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildImagePicker(),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        _buildErrorBox(_errorMessage!),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              _buildSubmitButton(label: 'SUBMIT', onTap: _onSubmit),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
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
        border: _daysError
            ? Border.all(color: const Color(0xFFE53935))
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Availability',
            style: TextStyle(color: Color(0xFF9B9B9B), fontSize: 12),
          ),
          const SizedBox(height: 4),
          ..._days.map((day) => _dayCheckbox(day)),
          if (_daysError)
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                'Select at least one day',
                style: TextStyle(
                    color: Color(0xFFE53935), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayCheckbox(String day) {
    final selected = _selectedDays.contains(day);
    return InkWell(
      onTap: () => setState(() {
        if (selected) {
          _selectedDays.remove(day);
        } else {
          _selectedDays.add(day);
        }
        _daysError = _selectedDays.isEmpty;
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: selected ? _pink : Colors.transparent,
                border: Border.all(
                  color: selected ? _pink : const Color(0xFFCCCCCC),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check,
                      color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              day,
              style: TextStyle(
                fontSize: 14,
                color: selected
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFF9B9B9B),
                fontWeight: selected
                    ? FontWeight.w500
                    : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShadowField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
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
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A1A)),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
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
            borderSide: const BorderSide(
                color: Color(0xFFE53935), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildImagePicker({String? existingUrl}) {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 130,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FC),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: const Color(0xFFEEEEEE), width: 1.5),
        ),
        child: _imageFile != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Image.file(_imageFile!,
                    fit: BoxFit.cover, width: double.infinity),
              )
            : existingUrl != null && existingUrl.isNotEmpty
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.network(existingUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Tap to change',
                            style: TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_outlined,
                          size: 36, color: Color(0xFFBBBBBB)),
                      SizedBox(height: 8),
                      Text(
                        'Tap to add meal photo',
                        style: TextStyle(
                            color: Color(0xFF9B9B9B), fontSize: 13),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style:
            const TextStyle(color: Color(0xFFE53935), fontSize: 13),
      ),
    );
  }

  Widget _buildSubmitButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(_pink),
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
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
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
