import 'package:flutter/material.dart';

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 32),
            Text(
              'WALLET',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: Color(0xFF1A1A1A),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'Coming soon',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF9B9B9B),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
