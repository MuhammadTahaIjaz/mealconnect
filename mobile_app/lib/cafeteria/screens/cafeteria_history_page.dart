import 'package:flutter/material.dart';

class CafeteriaHistoryPage extends StatelessWidget {
  const CafeteriaHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 32),
            Text(
              'HISTORY',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: Color(0xFF1A1A1A),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'Coming soon',
                  style: TextStyle(fontSize: 15, color: Color(0xFF9B9B9B)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
