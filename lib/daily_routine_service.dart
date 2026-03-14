import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class DailyRoutineService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  /// Initialiser les notifications quotidiennes (Android uniquement)
  static Future<void> initialize() async {
    // Initialiser les timezones
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Tunis'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(initSettings);
    await _requestPermissions();
  }

  static Future<void> _requestPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  /// Programmer TOUTES les notifications quotidiennes
  static Future<void> scheduleDailyRoutine() async {
    await cancelAllRoutineNotifications();

    // 7h00 - Réveil positif
    await _scheduleDailyNotification(
      id: 1001,
      hour: 7,
      minute: 0,
      title: 'Bonjour',
      body: 'Nouvelle journée remplie de possibilités. Prenez votre temps pour vous lever.',
    );

    // 8h00 - Petit-déjeuner
    await _scheduleDailyNotification(
      id: 1002,
      hour: 8,
      minute: 0,
      title: 'Petit-déjeuner',
      body: 'N\'oubliez pas de prendre votre petit-déjeuner. Prenez soin de vous.',
    );

    // 9h30 - Encouragement matinal
    await _scheduleDailyNotification(
      id: 1003,
      hour: 9,
      minute: 30,
      title: 'Vous allez bien',
      body: 'Vous êtes en sécurité. Tout va bien se passer aujourd\'hui.',
    );

    // 10h30 - Hydratation
    await _scheduleDailyNotification(
      id: 1004,
      hour: 10,
      minute: 30,
      title: 'Hydratation',
      body: 'Pensez à boire de l\'eau. Votre corps en a besoin.',
    );

    // 12h30 - Déjeuner
    await _scheduleDailyNotification(
      id: 1005,
      hour: 12,
      minute: 30,
      title: 'Déjeuner',
      body: 'C\'est l\'heure du déjeuner. Prenez le temps de bien manger.',
    );

    // 14h00 - Activité douce
    await _scheduleDailyNotification(
      id: 1006,
      hour: 14,
      minute: 0,
      title: 'Petit mouvement',
      body: 'Une petite promenade ou étirements vous feront du bien.',
    );

    // 15h30 - Hydratation
    await _scheduleDailyNotification(
      id: 1007,
      hour: 15,
      minute: 30,
      title: 'Hydratation',
      body: 'Buvez un verre d\'eau. Restez bien hydraté.',
    );

    // 16h30 - Affirmation positive
    await _scheduleDailyNotification(
      id: 1008,
      hour: 16,
      minute: 30,
      title: 'Vous êtes important',
      body: 'Vous êtes aimé et apprécié. Votre famille pense à vous.',
    );

    // 17h30 - Hydratation
    await _scheduleDailyNotification(
      id: 1009,
      hour: 17,
      minute: 30,
      title: 'Hydratation',
      body: 'N\'oubliez pas de boire de l\'eau.',
    );

    // 19h00 - Dîner
    await _scheduleDailyNotification(
      id: 1010,
      hour: 19,
      minute: 0,
      title: 'Dîner',
      body: 'C\'est l\'heure du dîner. Prenez votre temps pour manger.',
    );

    // 20h00 - Relaxation
    await _scheduleDailyNotification(
      id: 1011,
      hour: 20,
      minute: 0,
      title: 'Moment de calme',
      body: 'Prenez un moment pour vous détendre. Respirez profondément.',
    );

    // 21h00 - Préparation au coucher
    await _scheduleDailyNotification(
      id: 1012,
      hour: 21,
      minute: 0,
      title: 'Bonne nuit',
      body: 'Il est temps de vous reposer. Vous méritez un bon sommeil.',
    );

    print("[DailyRoutine] 12 notifications quotidiennes programmées");
  }

  /// Programmer une notification quotidienne récurrente
  static Future<void> _scheduleDailyNotification({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);

      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        'daily_routine_channel',
        'Routine quotidienne',
        channelDescription: 'Notifications de routine bien-être',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        icon: 'notification_icon',
      );

      const details = NotificationDetails(android: androidDetails);

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      print("[DailyRoutine] Programmé : $title à ${hour}h${minute}");
    } catch (e) {
      print("[DailyRoutine] Erreur : $e");
    }
  }

  /// Annuler toutes les notifications de routine
  static Future<void> cancelAllRoutineNotifications() async {
    for (int id = 1001; id <= 1012; id++) {
      await _notifications.cancel(id);
    }
    print("[DailyRoutine] Toutes les notifications annulées");
  }
}