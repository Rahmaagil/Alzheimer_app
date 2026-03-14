import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReminderNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
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

  static Future<void> scheduleReminder({
    required String reminderId,
    required String title,
    required DateTime scheduledTime,
  }) async {
    try {
      final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

      if (tzScheduledTime.isBefore(tz.TZDateTime.now(tz.local))) {
        print("[Notification] Rappel passé, ignoré");
        return;
      }

      const androidDetails = AndroidNotificationDetails(
        'reminder_channel',
        'Rappels',
        channelDescription: 'Notifications de rappels',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        icon: 'notification_icon',
      );

      const details = NotificationDetails(android: androidDetails);

      await _notifications.zonedSchedule(
        reminderId.hashCode,
        'Rappel',
        title,
        tzScheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
      );

      print("[Notification] Programmée: $title à $tzScheduledTime");
    } catch (e) {
      print("[Notification] Erreur: $e");
    }
  }

  static Future<void> cancelReminder(String reminderId) async {
    await _notifications.cancel(reminderId.hashCode);
  }

  static Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
  }

  static Future<void> scheduleAllReminders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reminders')
          .where('done', isEqualTo: false)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final title = data['title'] as String?;
        final timestamp = data['date'] as Timestamp?;

        if (title != null && timestamp != null) {
          final dateTime = timestamp.toDate();

          if (dateTime.isAfter(DateTime.now())) {
            await scheduleReminder(
              reminderId: doc.id,
              title: title,
              scheduledTime: dateTime,
            );
          }
        }
      }
    } catch (e) {
      print("[Notification] Erreur: $e");
    }
  }
}