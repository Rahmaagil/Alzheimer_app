import 'package:workmanager/workmanager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'fcm_service.dart';

class BackgroundService {

  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    print('[BackgroundService] Initialise');
  }

  static Future<void> startListening() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await Workmanager().registerPeriodicTask(
      "fcm-listener",
      "fcmListenerTask",
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );

    print('[BackgroundService] Listener demarre');
  }

  static Future<void> stopListening() async {
    await Workmanager().cancelByUniqueName("fcm-listener");
    print('[BackgroundService] Listener arrete');
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Reveille FCM toutes les 15 minutes
    print('[BackgroundService] Wake up FCM');
    return Future.value(true);
  });
}