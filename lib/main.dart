import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/database/local_storage_service.dart';
import 'services/supabase_service.dart';
import 'features/notifications/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'services/providers.dart';
import 'screens/main_shell.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/calculator/screens/calculator_screen.dart';
import 'features/profile/screens/about_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/schedule/screens/timetable_import_screen.dart';
import 'features/schedule/screens/timetable_review_screen.dart';
import 'features/subjects/screens/subject_import_screen.dart';
import 'features/subjects/screens/subject_review_screen.dart';

void main() async {
  // Ensure Flutter engine binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Critical Error: Failed to load .env file: $e');
  }

  // Initialize Local Cache and Services with safety try-catch boundaries
  try {
    await LocalStorageService.init();
  } catch (e) {
    debugPrint('Critical Error: LocalStorageService init failed: $e');
  }

  try {
    await SupabaseService.init();
  } catch (e) {
    debugPrint('Critical Error: SupabaseService init failed: $e');
  }

  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('Critical Error: NotificationService init failed: $e');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    // Watch auth status to trigger route redirection dynamically
    final authUser = ref.watch(authProvider);

    final GoRouter router = GoRouter(
      initialLocation: authUser != null ? '/home' : '/login',
      redirect: (context, state) {
        final bool loggedIn = authUser != null;
        final bool onAuthPath = state.matchedLocation == '/login' ||
            state.matchedLocation == '/signup' ||
            state.matchedLocation == '/forgot-password';

        if (!loggedIn && !onAuthPath) {
          return '/login';
        }
        if (loggedIn && onAuthPath) {
          return '/home';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          redirect: (_, __) => '/home',
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const MainShell(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => const SignupScreen(),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: '/calculator',
          builder: (context, state) => const CalculatorScreen(),
        ),
        GoRoute(
          path: '/about',
          builder: (context, state) => const AboutScreen(),
        ),
        GoRoute(
          path: '/import-timetable',
          builder: (context, state) => const TimetableImportScreen(),
        ),
        GoRoute(
          path: '/review-timetable',
          builder: (context, state) {
            return TimetableReviewScreen(slots: state.extra as List<dynamic>? ?? []);
          },
        ),
        GoRoute(
          path: '/import-subjects',
          builder: (context, state) => const SubjectImportScreen(),
        ),
        GoRoute(
          path: '/review-subjects',
          builder: (context, state) {
            return SubjectReviewScreen(subjects: state.extra as List<dynamic>? ?? []);
          },
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Bunk Mitra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
