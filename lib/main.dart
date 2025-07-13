import 'package:flutter/material.dart';
import 'package:bizcard_snap/services/api_service.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/bottom_nav_bar.dart';
import 'pages/forgot_password_page.dart';
import 'pages/reset_password_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BizCardSnapApp());
}

class BizCardSnapApp extends StatelessWidget {
  const BizCardSnapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BizCardSnap',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(decoration: TextDecoration.none),
          bodyMedium: TextStyle(decoration: TextDecoration.none),
          bodySmall: TextStyle(decoration: TextDecoration.none),
          labelLarge: TextStyle(decoration: TextDecoration.none),
          labelMedium: TextStyle(decoration: TextDecoration.none),
          labelSmall: TextStyle(decoration: TextDecoration.none),
          displayLarge: TextStyle(decoration: TextDecoration.none),
          displayMedium: TextStyle(decoration: TextDecoration.none),
          displaySmall: TextStyle(decoration: TextDecoration.none),
          headlineLarge: TextStyle(decoration: TextDecoration.none),
          headlineMedium: TextStyle(decoration: TextDecoration.none),
          headlineSmall: TextStyle(decoration: TextDecoration.none),
          titleLarge: TextStyle(decoration: TextDecoration.none),
          titleMedium: TextStyle(decoration: TextDecoration.none),
          titleSmall: TextStyle(decoration: TextDecoration.none),
        ),
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/home': (context) => const BottomNavBar(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/reset-password': (context) => const ResetPasswordPage(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    print('Starting auth check');
    final apiService = ApiService();
    await apiService.init(); // Wait for token to load
    final isAuthenticated = await apiService.isAuthenticated();
    print('isAuthenticated result: $isAuthenticated');
    if (isAuthenticated) {
      print('Valid token found, navigating to /home');
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      print('No valid token, navigating to /login');
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
        ),
      ),
    );
  }
}