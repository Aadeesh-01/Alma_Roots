import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cs261_project/firebase_options.dart';
import 'package:cs261_project/screen/auth.dart';
import 'package:cs261_project/screen/splash_screen.dart';
import 'package:cs261_project/service/user_role_dispatcher.dart';
import 'package:cs261_project/service/theme_service.dart';
import 'package:cs261_project/service/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cs261_project/theme/app_theme.dart';

final themeService = ThemeService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeService.init();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    debugPrint("✅ Firebase initialized successfully!");
  } catch (e) {
    debugPrint("❌ Firebase initialization failed: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _lastInstituteId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInstituteId();
  }

  Future<void> _loadInstituteId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastInstituteId = prefs.getString('lastInstituteId');
      _isLoading = false;
    });
   // print("🏫 Loaded institute ID: $_lastInstituteId");
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(home: SplashScreen());
    }

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: NotificationService.navigatorKey,
          title: 'Alma Roots',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.themeMode,
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              }

              if (snapshot.hasData) {
               // print("🚀 Logged in as: ${snapshot.data!.uid}");
                if (_lastInstituteId != null) {
                 // print("✅ Using institute from prefs: $_lastInstituteId");
                  return UserRoleDispatcher(instituteId: _lastInstituteId!);
                } else {
                  //print("⚠️ No institute found in prefs — redirecting to AuthScreen");
                  return const AuthScreen();
                }
              } else {
                return const AuthScreen();
              }
            },
          ),
        );
      }
    );
  }
}
