import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/pending_approval_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MealConnectCafeteriaApp());
}

class MealConnectCafeteriaApp extends StatelessWidget {
  const MealConnectCafeteriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MealConnect Cafeteria',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF3366)),
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      initialRoute: '/splash',
      routes: {
        '/splash':             (context) => const SplashScreen(),
        '/cafeteria-signin':   (context) => const SignInScreen(),
        '/cafeteria-signup':   (context) => const SignUpScreen(),
        '/cafeteria-pending':  (context) => const PendingApprovalScreen(),
        // Routes to be added as screens are built:
        // '/cafeteria-home':  (context) => const CafeteriaHomeScreen(),
      },
    );
  }
}
