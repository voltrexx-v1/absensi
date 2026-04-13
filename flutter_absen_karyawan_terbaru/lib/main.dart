import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/app_constants.dart';
import 'models/user_model.dart';
import 'views/login_screen.dart';
import 'views/main_layout.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting for intl package
  await initializeDateFormatting('id_ID', null);

  // Firebase initialization removed

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UNITED TRACTORS.Tbk.',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthWrapperApp(),
    );
  }
}

// --- AUTH WRAPPER APP ---
class AuthWrapperApp extends StatefulWidget {
  const AuthWrapperApp({super.key});

  @override
  State<AuthWrapperApp> createState() => _AuthWrapperAppState();
}

class _AuthWrapperAppState extends State<AuthWrapperApp> {
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Fungsi baca SharedPreferences dihapus.
    // Aplikasi tidak lagi mengingat status login sebelumnya secara otomatis.
    // Ketika aplikasi ditutup (close app) dan dibuka lagi, akan selalu kembali ke Login.
    setState(() => _isLoading = false);
  }

  void _login(UserModel user) async {
    // Simpan sesi hanya di state/memori sementara, tidak di penyimpanan permanen
    setState(() => _currentUser = user);
  }

  void _logout() async {
    // Hapus sesi dari memori dan backend
    await ApiService.logout();
    setState(() => _currentUser = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.slate900,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.yellow500),
        ),
      );
    }
    return _currentUser == null
        ? LoginScreen(onLogin: _login)
        : MainLayout(user: _currentUser!, onLogout: _logout);
  }
}
