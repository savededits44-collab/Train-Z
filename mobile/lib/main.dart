import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'routing/app_router.dart';
import 'services/location_service.dart';
import 'services/push_notification_service.dart';
import 'splashscreen/splashscreen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with native configurations (google-services.json)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  // Initialize central application-wide location service (defaults to Pune, Maharashtra)
  try {
    await LocationService.instance.initialize();
  } catch (e) {
    debugPrint('LocationService initialization notice: $e');
  }

  // Initialize push notification service (FCM)
  try {
    await PushNotificationService.instance.initialize();
  } catch (e) {
    debugPrint('PushNotificationService initialization notice: $e');
  }

  // Set system UI style for ultra-clean edge-to-edge dark luxury
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.pureBlack,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const TrainusproApp());
}

class TrainusproApp extends StatelessWidget {
  const TrainusproApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trainz',
      debugShowCheckedModeBanner: false,
      navigatorKey: PushNotificationService.navigatorKey,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
