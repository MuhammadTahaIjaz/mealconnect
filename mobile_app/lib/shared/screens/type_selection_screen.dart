import 'package:flutter/material.dart';

class TypeSelectionScreen extends StatefulWidget {
  const TypeSelectionScreen({super.key});

  @override
  State<TypeSelectionScreen> createState() => _TypeSelectionScreenState();
}

class _TypeSelectionScreenState extends State<TypeSelectionScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedType; // 'parents' or 'cafeteria'

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onContinue() {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a type to continue.'),
          backgroundColor: Color(0xFFFF3366),
        ),
      );
      return;
    }

    if (_selectedType == 'parents') {
      Navigator.pushNamed(context, '/parent-signin');
    } else {
      Navigator.pushNamed(context, '/cafeteria-signin');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFF3366),
              Color(0xFFFF6633),
              Color(0xFFFF8C00),
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),

                    // ── App Name ──
                    const Text(
                      'MealConnect',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 42,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),

                    const Spacer(),

                    // ── TYPE SELECTION label ──
                    const Text(
                      'TYPE SELECTION',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 2.5,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Selection Cards ──
                    Row(
                      children: [
                        // Parents Card
                        Expanded(
                          child: _SelectionCard(
                            label: 'Parents',
                            icon: Icons.people_outline_rounded,
                            isSelected: _selectedType == 'parents',
                            onTap: () =>
                                setState(() => _selectedType = 'parents'),
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Cafeteria Card
                        Expanded(
                          child: _SelectionCard(
                            label: 'Cafeteria',
                            icon: Icons.store_mall_directory_outlined,
                            isSelected: _selectedType == 'cafeteria',
                            onTap: () =>
                                setState(() => _selectedType = 'cafeteria'),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // ── Continue Button ──
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _onContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFFF3366),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                        ),
                        child: const Text(
                          'CONTINUE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                            color: Color(0xFFFF3366),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reusable Selection Card Widget ──────────────────────────────────────────

class _SelectionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF3366) : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: isSelected
                  ? const Color(0xFFFF3366)
                  : Colors.black87,
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? const Color(0xFFFF3366)
                    : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}