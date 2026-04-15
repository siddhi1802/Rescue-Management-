import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'models/report_model.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signUp_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/user/home_screen.dart';
import 'screens/user/map_screen.dart';
import 'screens/user/report_screen.dart';
import 'screens/user/report_history.dart';
import 'screens/user/report_detail_screen.dart';
import 'screens/user/edit_profile_screen.dart';
import 'screens/user/emergency_contacts_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/Ngo/Ngo_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService().initialize();

  runApp(const RescueApp());
}

class RescueApp extends StatelessWidget {
  const RescueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'RescueConnect',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/',
        onGenerateRoute: _generateRoute,
      ),
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return _route(const SplashScreen());

      case '/login':
        return _route(const LoginScreen());

      case '/signup':
        return _route(const SignUpScreen());

      case '/forgot-password':
        return _route(const ForgotPasswordScreen());

      case '/home':
        return _route(const HomeScreen());

      case '/map':
        return _route(const MapScreen());

      case '/report':
        final type = settings.arguments as ReportType?;
        return _route(ReportScreen(initialType: type));

      case '/report-history':
        return _route(const ReportHistoryScreen());

      case '/report-detail':
        final report = settings.arguments as ReportModel;
        return _route(ReportDetailScreen(report: report));

      case '/edit-profile':
        return _route(const EditProfileScreen());

      case '/emergency-contacts':
        return _route(const EmergencyContactsScreen());

      case '/admin':
        return _route(const AdminDashboard());

      case '/ngo':
        return _route(const NgoDashboard());

      default:
        return _route(const LoginScreen());
    }
  }

  PageRouteBuilder _route(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        final tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        final offsetAnimation = animation.drive(tween);
        return SlideTransition(position: offsetAnimation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 280),
    );
  }
}