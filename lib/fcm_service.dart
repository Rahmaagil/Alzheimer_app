import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("[FCM Background] Message recu: ${message.notification?.title}");
}

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static StreamSubscription? _firestoreSubscription;

  static Future<void> initialize() async {
    debugPrint('[FCM] Initialisation complete...');

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('[FCM] Permissions refusees');
        return;
      }

      debugPrint('[FCM] Permissions accordees');

      await _initializeLocalNotifications();
      await _createNotificationChannels();
      await _setupMessageHandlers();
      await _setupTokenManagement();

      debugPrint('[FCM] Initialise avec succes');
    } catch (e) {
      debugPrint('[FCM] Erreur initialisation: $e');
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('[FCM] Notification cliquee: ${details.payload}');
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation
    <AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  static Future<void> _createNotificationChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation
    <AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    const alertsChannel = AndroidNotificationChannel(
      'alzhecare_alerts',
      'Alertes Urgentes',
      description: 'Alertes SOS, chutes et sorties de zone',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      ledColor: Color(0xFFFF0000),
    );

    const remindersChannel = AndroidNotificationChannel(
      'alzhecare_reminders',
      'Rappels',
      description: 'Rappels medicaments et routines',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    const routineChannel = AndroidNotificationChannel(
      'alzhecare_routine',
      'Routine quotidienne',
      description: 'Notifications de routine',
      importance: Importance.defaultImportance,
      playSound: true,
    );

    await androidPlugin.createNotificationChannel(alertsChannel);
    await androidPlugin.createNotificationChannel(remindersChannel);
    await androidPlugin.createNotificationChannel(routineChannel);

    debugPrint('[FCM] Canaux crees');
  }

  static Future<void> _setupMessageHandlers() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM Foreground] Message: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] App ouverte via notification');
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] App lancee via notification');
    }
  }

  static Future<void> _setupTokenManagement() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[FCM] Pas d\'utilisateur connecte');
        return;
      }

      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(user.uid, token);
      }

      _messaging.onTokenRefresh.listen((newToken) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          _saveToken(currentUser.uid, newToken);
        }
      });
    } catch (e) {
      debugPrint('[FCM] Erreur setup token: $e');
    }
  }

  static Future<void> _saveToken(String uid, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[FCM] Token sauvegarde');
    } catch (e) {
      debugPrint('[FCM] Erreur sauvegarde token: $e');
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final alertType = message.data['type']?.toString() ?? '';
    final channelId = _getChannelIdForType(alertType);
    final importance = _getImportanceForType(alertType);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelNameForType(alertType),
      channelDescription: _getChannelDescForType(alertType),
      importance: importance,
      priority: importance == Importance.max ? Priority.max : Priority.high,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF4A90E2),
      styleInformation: BigTextStyleInformation(
        notification.body ?? '',
        contentTitle: notification.title,
      ),
    );

    final details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      notification.title ?? 'AlzheCare',
      notification.body ?? 'Nouvelle notification',
      details,
      payload: message.data.toString(),
    );
  }

  static Future<void> startListeningFirestoreAlerts(String caregiverUid) async {
    debugPrint('[FCM] Ecoute Firestore pour: $caregiverUid');

    await _firestoreSubscription?.cancel();

    _firestoreSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('caregiverId', isEqualTo: caregiverUid)  // CORRECTION ICI
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)  // CORRECTION ICI (etait 'createdAt')
        .snapshots()
        .listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>?;
          if (data != null) {
            await _showFirestoreNotification(change.doc.id, data);
          }
        }
      }
    });
  }

  static Future<void> stopListeningFirestoreAlerts() async {
    await _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
  }

  static Future<void> _showFirestoreNotification(
      String notifId, Map<String, dynamic> notif) async {
    final notification = notif['notification'] as Map<String, dynamic>?;
    final title = notification?['title'] ?? 'AlzheCare';
    final body = notification?['body'] ?? 'Nouvelle alerte';

    await _localNotifications.show(
      notifId.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'alzhecare_alerts',
          'Alertes Urgentes',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );

    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(notifId)
        .update({
      'status': 'delivered',
      'deliveredAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> sendNotificationToCaregiver({
    required String patientUid,
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final patientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .get();

      final caregiverUid = patientDoc.data()?['linkedCaregiver'] as String?;

      if (caregiverUid == null) {
        debugPrint('[FCM] Aucun caregiver lie');
        return;
      }

      final caregiverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverUid)
          .get();

      final fcmToken = caregiverDoc.data()?['fcmToken'] as String?;

      if (fcmToken == null) {
        debugPrint('[FCM] Caregiver sans token FCM');
        return;
      }

      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'caregiverUid': caregiverUid,
        'to': fcmToken,
        'notification': {
          'title': title,
          'body': body,
        },
        'data': {
          ...?data,
          'type': type ?? '',
          'patientUid': patientUid,
        },
        'priority': 'high',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      debugPrint('[FCM] Notification creee pour caregiver');
    } catch (e) {
      debugPrint('[FCM] Erreur: $e');
    }
  }

  static Future<void> sendSOSAlert({
    required String patientUid,
    double? latitude,
    double? longitude,
  }) async {
    await sendNotificationToCaregiver(
      patientUid: patientUid,
      title: 'ALERTE SOS',
      body: 'Le patient a declenche une alerte SOS',
      type: 'sos',
      data: {
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  static Future<void> sendFallAlert({
    required String patientUid,
    double? latitude,
    double? longitude,
  }) async {
    await sendNotificationToCaregiver(
      patientUid: patientUid,
      title: 'Chute detectee',
      body: 'Une chute a ete detectee',
      type: 'fall',
      data: {
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  static Future<void> sendGeofenceAlert({
    required String patientUid,
    required int distance,
    double? latitude,
    double? longitude,
  }) async {
    await sendNotificationToCaregiver(
      patientUid: patientUid,
      title: 'Sortie de zone',
      body: 'Le patient est sorti de la zone securisee ($distance m)',
      type: 'geofence',
      data: {
        'distance': distance,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  static Future<void> showGeofenceAlert({required int distance}) async {
    await _localNotifications.show(
      1,
      'Alerte de securite',
      'Le patient est sorti de la zone securisee ($distance m)',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'alzhecare_alerts',
          'Alertes Urgentes',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  static Future<void> deleteToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': FieldValue.delete()});
      }

      await _messaging.deleteToken();
      debugPrint('[FCM] Token supprime');
    } catch (e) {
      debugPrint('[FCM] Erreur suppression: $e');
    }
  }

  static String _getChannelIdForType(String type) {
    switch (type.toLowerCase()) {
      case 'sos':
      case 'fall':
      case 'geofence':
        return 'alzhecare_alerts';
      case 'reminder':
      case 'medication':
        return 'alzhecare_reminders';
      case 'routine':
        return 'alzhecare_routine';
      default:
        return 'alzhecare_alerts';
    }
  }

  static String _getChannelNameForType(String type) {
    switch (type.toLowerCase()) {
      case 'reminder':
      case 'medication':
        return 'Rappels';
      case 'routine':
        return 'Routine quotidienne';
      default:
        return 'Alertes Urgentes';
    }
  }

  static String _getChannelDescForType(String type) {
    switch (type.toLowerCase()) {
      case 'reminder':
      case 'medication':
        return 'Rappels medicaments et routines';
      case 'routine':
        return 'Notifications de routine';
      default:
        return 'Alertes SOS, chutes et sorties de zone';
    }
  }

  static Importance _getImportanceForType(String type) {
    switch (type.toLowerCase()) {
      case 'sos':
      case 'fall':
        return Importance.max;
      case 'geofence':
      case 'reminder':
        return Importance.high;
      default:
        return Importance.defaultImportance;
    }
  }
}