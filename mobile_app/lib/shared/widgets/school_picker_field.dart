import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolPickerField extends StatelessWidget {
  final String? selectedId;
  final String? selectedName;
  final bool hasError;
  final Function(String schoolId, String schoolName) onSelected;

  const SchoolPickerField({
    super.key,
    required this.onSelected,
    this.selectedId,
    this.selectedName,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedName != null && selectedName!.isNotEmpty;
    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
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
          border: hasError
              ? Border.all(color: const Color(0xFFE53935))
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            const Icon(Icons.school_outlined,
                color: Color(0xFF9B9B9B), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isSelected ? selectedName! : 'Select your school',
                style: TextStyle(
                  fontSize: isSelected ? 15 : 14,
                  fontWeight:
                      isSelected ? FontWeight.w500 : FontWeight.w400,
                  color: isSelected
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFF9B9B9B),
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down,
                color: Color(0xFF9B9B9B), size: 22),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _SchoolPickerDialog(
        currentId: selectedId,
        onSelected: onSelected,
      ),
    );
  }
}

class _SchoolPickerDialog extends StatefulWidget {
  final String? currentId;
  final Function(String schoolId, String schoolName) onSelected;

  const _SchoolPickerDialog({required this.onSelected, this.currentId});

  @override
  State<_SchoolPickerDialog> createState() => _SchoolPickerDialogState();
}

class _SchoolPickerDialogState extends State<_SchoolPickerDialog> {
  static const _pink = Color(0xFFFF3366);

  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchSchools();
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSchools() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('schools')
          .orderBy('name')
          .get();
      final list = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();
      if (mounted) {
        setState(() {
          _all = list;
          _filtered = List.from(list);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(_all);
      } else {
        _filtered = _all.where((s) {
          final name = ((s['name'] as String?) ?? '').toLowerCase();
          final branch = ((s['branch'] as String?) ?? '').toLowerCase();
          final display =
              ((s['displayName'] as String?) ?? '').toLowerCase();
          return name.contains(q) ||
              branch.contains(q) ||
              display.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const Text(
                  'Select School',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close,
                      color: Color(0xFF9B9B9B), size: 22),
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search by school or branch name…',
                hintStyle: const TextStyle(
                    color: Color(0xFF9B9B9B), fontSize: 14),
                prefixIcon: const Icon(Icons.search,
                    color: Color(0xFF9B9B9B), size: 20),
                filled: true,
                fillColor: const Color(0xFFF7F8FC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),

          const Divider(height: 1, color: Color(0xFFEEEEEE)),

          // List
          SizedBox(
            height: 320,
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(_pink),
                  ))
                : _filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No schools found.',
                          style: TextStyle(
                              color: Color(0xFF9B9B9B), fontSize: 14),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const Divider(
                            height: 1, color: Color(0xFFF0F0F0),
                            indent: 56),
                        itemBuilder: (context, i) {
                          final s = _filtered[i];
                          final id = s['id'] as String;
                          final name = (s['name'] as String?) ?? '';
                          final branch =
                              (s['branch'] as String?) ?? '';
                          final displayName =
                              (s['displayName'] as String?) ?? name;
                          final isSelected = id == widget.currentId;

                          return ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? _pink.withValues(alpha: 0.12)
                                    : const Color(0xFFF7F8FC),
                              ),
                              child: Icon(
                                Icons.school_outlined,
                                size: 18,
                                color: isSelected
                                    ? _pink
                                    : const Color(0xFF9B9B9B),
                              ),
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? _pink
                                    : const Color(0xFF1A1A1A),
                              ),
                            ),
                            subtitle: branch.isNotEmpty
                                ? Text(
                                    branch,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF9B9B9B),
                                    ),
                                  )
                                : null,
                            trailing: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: _pink, size: 20)
                                : null,
                            onTap: () {
                              widget.onSelected(id, displayName);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
