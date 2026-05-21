import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Shared
import 'shared/screens/splash_screen.dart';
import 'shared/screens/type_selection_screen.dart';

// Parent
import 'parent/screens/sign_in_screen.dart'              as parent_sign_in;
import 'parent/screens/sign_up_screen.dart'              as parent_sign_up;
import 'parent/screens/children_details_screen.dart'     as parent_children;
import 'parent/screens/add_child_screen.dart'            as parent_add_child;
import 'parent/screens/pending_approval_screen.dart'     as parent_pending;
import 'parent/screens/home_shell.dart'                  as parent_home;

// Cafeteria
import 'cafeteria/screens/sign_in_screen.dart'           as cafeteria_sign_in;
import 'cafeteria/screens/sign_up_screen.dart'           as cafeteria_sign_up;
import 'cafeteria/screens/pending_approval_screen.dart'  as cafeteria_pending;
import 'cafeteria/screens/home_shell.dart'               as cafeteria_home;
import 'cafeteria/screens/add_meal_screen.dart'          as cafeteria_add_meal;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MealConnectApp());
}

class MealConnectApp extends StatelessWidget {
  const MealConnectApp({super.key});

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
        // ── Shared ────────────────────────────────────────────────────────
        '/splash':                  (context) => const SplashScreen(),
        '/type-selection':          (context) => const TypeSelectionScreen(),

        // ── Parent ────────────────────────────────────────────────────────
        '/parent-signin':           (context) => const parent_sign_in.SignInScreen(),
        '/parent-signup':           (context) => const parent_sign_up.SignUpScreen(),
        '/parent-children-details': (context) => const parent_children.ChildrenDetailsScreen(),
        '/parent-add-child':        (context) => const parent_add_child.AddChildScreen(),
        '/parent-pending':          (context) => const parent_pending.PendingApprovalScreen(),
        '/parent-home':             (context) => const parent_home.HomeShell(),

        // ── Cafeteria ─────────────────────────────────────────────────────
        '/cafeteria-signin':        (context) => const cafeteria_sign_in.SignInScreen(),
        '/cafeteria-signup':        (context) => const cafeteria_sign_up.SignUpScreen(),
        '/cafeteria-pending':        (context) => const cafeteria_pending.PendingApprovalScreen(),
        '/cafeteria-home':           (context) => const cafeteria_home.HomeShell(),
        '/cafeteria-add-meal':       (context) => const cafeteria_add_meal.AddMealScreen(),
      },
    );
  }
}
