import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'services/auth_service.dart';
import 'services/location_service.dart';
import 'services/push_notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: After Firebase setup, uncomment these:
  // import 'package:firebase_core/firebase_core.dart';
  // await Firebase.initializeApp();

  // Initialize background location service
  await LocationService.initializeBackgroundService();

  // Initialize push notifications
  // TODO: After Firebase setup, uncomment:
  // await PushNotificationService.instance.initialize();

  runApp(const KilifiHubRiderApp());
}

class KilifiHubRiderApp extends StatelessWidget {
  const KilifiHubRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: AppConfig.APP_NAME,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(AppConfig.PRIMARY_COLOR),
          brightness: Brightness.light,
          fontFamily: AppConfig.FONT_FAMILY,
          scaffoldBackgroundColor: const Color(AppConfig.BACKGROUND_COLOR),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Color(AppConfig.TEXT_PRIMARY),
            elevation: 0,
            centerTitle: false,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
              ),
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(AppConfig.BACKGROUND_COLOR),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConfig.RADIUS_LG),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

/// Auth wrapper - checks if rider is logged in and shows appropriate screen
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    await auth.checkSession();
    setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.delivery_dining,
                size: 64,
                color: Color(AppConfig.PRIMARY_COLOR),
              ),
              SizedBox(height: 16),
              Text(
                AppConfig.APP_NAME,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(AppConfig.PRIMARY_COLOR),
                ),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(
                color: Color(AppConfig.PRIMARY_COLOR),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<AuthService>(
      builder: (context, auth, _) {
        if (auth.isLoggedIn) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
