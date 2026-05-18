import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/type_selection_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF3366)),
        useMaterial3: true,
        fontFamily: 'Poppins',
      ),
      initialRoute: '/splash',
      routes: {
        '/splash':                   (context) => const SplashScreen(),
        '/type-selection':           (context) => const TypeSelectionScreen(),
        '/parent-signin':            (context) => const SignInScreen(),
        '/parent-signup':            (context) => const SignUpScreen(),
        '/parent-home':              (context) => const HomeScreen(),
        // Routes to be added as screens are built:
        // '/parent-children-details': (context) => const ChildrenDetailsScreen(),
      },
    );
  }
}
