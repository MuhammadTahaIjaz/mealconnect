import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'screens/type_selection_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MealConnect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF3366),
        ),
        useMaterial3: true,
      ),

      // ── Initial Screen ──
      initialRoute: '/splash',

      // ── Routes ──
      routes: {
        '/splash':         (context) => const SplashScreen(),
        '/type-selection': (context) => const TypeSelectionScreen(),

        // Add more routes here as you build more screens:
        // '/parent-login':    (context) => const ParentLoginScreen(),
        // '/cafeteria-login': (context) => const CafeteriaLoginScreen(),
      },
    );
  }
}
