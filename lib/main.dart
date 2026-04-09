import 'package:alzhecare/daily_routine_service.dart';
import 'package:alzhecare/face_recognition_service.dart';
import 'package:alzhecare/fcm_service.dart';
import 'package:alzhecare/sign_up_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'background_service.dart';
import 'geofencing_service.dart';
import 'fall_detection_background_service.dart';

/// Clé globale du Navigator pour afficher des dialogs depuis n'importe quel contexte
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  tz.initializeTimeZones();

  await FCMService.initialize();
  await GeofencingService.initialize();
  await FaceRecognitionService.initialize();
  await DailyRoutineService.initialize();
  await BackgroundService.initialize();

  // Injecter le navigatorKey dans le service de détection de chute
  FallDetectionBackgroundService.navigatorKey = navigatorKey;

  final prefs = await SharedPreferences.getInstance();
  final isRoutineEnabled = prefs.getBool('daily_routine_enabled') ?? false;
  if (isRoutineEnabled) {
    await DailyRoutineService.scheduleDailyRoutine();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'AlzheCare',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const SignUpScreen(),
    );
  }
}