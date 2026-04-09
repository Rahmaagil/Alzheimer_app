import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'fall_detection_service.dart';

class FallDetectionBackgroundService {
  /// NavigatorKey global injecté depuis main.dart
  static GlobalKey<NavigatorState>? navigatorKey;

  static FallDetectionService? _fallService;
  static bool _isRunning = false;
  static bool _isProcessingFall = false;

  /// Démarre la surveillance en arrière-plan pour un patient
  static Future<void> startForPatient() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final role = userDoc.data()?['role'];
    if (role != 'patient') return;

    if (_isRunning) return;

    _fallService = FallDetectionService();
    try {
      await _fallService!.initialize();
    } catch (e) {
      print('[BgFallDetection] Erreur initialisation: $e');
      _fallService = null;
      return;
    }

    _fallService!.onFallDetected = (isFall, confidence) {
      if (isFall && !_isProcessingFall) {
        _handleFallDetected(confidence);
      }
    };

    _fallService!.startMonitoring();
    _isRunning = true;
    print('[BgFallDetection] Service démarré en arrière-plan');
  }

  /// Gère la détection d'une chute : affiche le dialog de confirmation au patient
  static void _handleFallDetected(double confidence) async {
    if (_isProcessingFall) return;
    _isProcessingFall = true;

    _fallService?.pauseDetection();
    print('[BgFallDetection] Chute détectée, affichage dialog confirmation');

    final ctx = navigatorKey?.currentContext;
    if (ctx == null) {
      // Pas de contexte disponible → envoyer alerte automatiquement
      print('[BgFallDetection] Pas de contexte, envoi alerte auto');
      await _sendFallAlert(confidence, 'auto');
      _isProcessingFall = false;
      _fallService?.resumeDetection();
      return;
    }

    try {
      final result = await Navigator.of(ctx, rootNavigator: true).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _FallConfirmationScreen(confidence: confidence),
        ),
      );

      if (result == true) {
        // Patient confirme avoir besoin d'aide
        await _sendFallAlert(confidence, 'patient');
      } else if (result == null) {
        // Timer expiré → alerte automatique
        await _sendFallAlert(confidence, 'auto');
      }
      // result == false → Patient dit "je vais bien" → aucune alerte
    } catch (e) {
      print('[BgFallDetection] Erreur dialog: $e');
      await _sendFallAlert(confidence, 'auto');
    } finally {
      _isProcessingFall = false;
      await Future.delayed(const Duration(seconds: 5));
      _fallService?.resumeDetection();
    }
  }

  /// Envoie une notification de chute à tous les caregivers liés
  static Future<void> _sendFallAlert(double confidence, String confirmedBy) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      print('[BgFallDetection] Envoi alerte chute (confirmedBy: $confirmedBy)');

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final patientName = userDoc.data()?['name'] ?? 'Patient';
      final linkedCaregiversRaw = userDoc.data()?['linkedCaregivers'];

      List<String> linkedCaregivers = [];
      if (linkedCaregiversRaw is List) {
        linkedCaregivers = linkedCaregiversRaw
            .where((id) => id != null && id.toString().isNotEmpty)
            .map((id) => id.toString())
            .toList();
      }

      if (linkedCaregivers.isEmpty) {
        print('[BgFallDetection] Aucun caregiver lié');
        return;
      }

      // Récupérer la dernière position GPS
      GeoPoint? location;
      double? latitude, longitude;

      try {
        final locationDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('locations')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (locationDoc.docs.isNotEmpty) {
          location = locationDoc.docs.first.data()['location'] as GeoPoint?;
          if (location != null) {
            latitude = location.latitude;
            longitude = location.longitude;
          }
        }
      } catch (e) {
        print('[BgFallDetection] Erreur récupération position: $e');
      }

      // Envoyer la notification à chaque caregiver
      for (final caregiverId in linkedCaregivers) {
        try {
          await FirebaseFirestore.instance.collection('notifications').add({
            'caregiverId': caregiverId,
            'patientId': user.uid,
            'patientName': patientName,
            'type': 'fall',
            'title': 'Alerte Chute Détectée',
            'message': confirmedBy == 'patient'
                ? '$patientName a confirmé être tombé(e) (${(confidence * 100).toStringAsFixed(0)}% confiance)'
                : '$patientName — Chute détectée automatiquement (${(confidence * 100).toStringAsFixed(0)}% confiance)',
            'location': location,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'pending',
            'confidence': confidence,
            'confirmed': confirmedBy,
            'latitude': latitude,
            'longitude': longitude,
            'isRead': false,
          });
          print('[BgFallDetection] Notification envoyée à caregiver: $caregiverId');
        } catch (e) {
          print('[BgFallDetection] Erreur envoi à $caregiverId: $e');
        }
      }
    } catch (e) {
      print('[BgFallDetection] Erreur générale: $e');
    }
  }

  /// Retourne l'instance du service de détection (pour PatientFallMonitorScreen)
  static FallDetectionService? get fallService => _fallService;

  /// Vérifie si le service est actif
  static bool get isRunning => _isRunning;

  /// Pause la détection (appelé depuis PatientFallMonitorScreen)
  static void pauseDetection() => _fallService?.pauseDetection();

  /// Reprend la détection (appelé depuis PatientFallMonitorScreen)
  static void resumeDetection() => _fallService?.resumeDetection();

  static void stop() {
    _fallService?.stopMonitoring();
    _fallService?.dispose();
    _fallService = null;
    _isRunning = false;
    _isProcessingFall = false;
    print('[BgFallDetection] Service arrêté');
  }
}

// ─────────────────────────────────────────────────────────────
// Widget : Dialog de confirmation chute (affiché au patient)
// ─────────────────────────────────────────────────────────────

class _FallConfirmationScreen extends StatefulWidget {
  final double confidence;
  const _FallConfirmationScreen({required this.confidence});

  @override
  State<_FallConfirmationScreen> createState() => _FallConfirmationScreenState();
}

class _FallConfirmationScreenState extends State<_FallConfirmationScreen>
    with SingleTickerProviderStateMixin {
  int _secondsRemaining = 30;
  Timer? _timer;
  bool _hasResponded = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _hasResponded) {
        timer.cancel();
        return;
      }
      setState(() => _secondsRemaining--);
      if (_secondsRemaining <= 0) {
        timer.cancel();
        _respond(null); // timer expiré = alerte auto
      }
    });
  }

  void _respond(bool? needHelp) {
    if (_hasResponded) return;
    setState(() => _hasResponded = true);
    _timer?.cancel();
    if (mounted) Navigator.of(context).pop(needHelp);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_secondsRemaining / 30).clamp(0.0, 1.0);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFEBEE),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icône pulsante
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF5F6D), Color(0xFFFF2E63)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF5F6D).withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.warning_amber_rounded, size: 70, color: Colors.white),
                  ),
                ),

                const SizedBox(height: 36),

                const Text(
                  'Chute Détectée !',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD32F2F),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Confiance : ${(widget.confidence * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 16, color: Colors.black54),
                ),

                const SizedBox(height: 28),

                // Compte à rebours avec cercle de progression
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: pct,
                        strokeWidth: 8,
                        backgroundColor: Colors.red.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          pct > 0.5 ? const Color(0xFF66BB6A) : const Color(0xFFFF5F6D),
                        ),
                      ),
                    ),
                    Text(
                      _hasResponded ? '...' : '$_secondsRemaining',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD32F2F),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                const Text(
                  'Allez-vous bien ?',
                  style: TextStyle(fontSize: 24, color: Colors.black87, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 12),

                Text(
                  'Si aucune réponse dans $_secondsRemaining sec,\nune alerte sera envoyée automatiquement.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black45),
                ),

                const SizedBox(height: 40),

                // Bouton JE VAIS BIEN
                SizedBox(
                  width: double.infinity,
                  height: 68,
                  child: ElevatedButton(
                    onPressed: _hasResponded ? null : () => _respond(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasResponded ? Colors.grey : const Color(0xFF66BB6A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: _hasResponded ? 0 : 6,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 30,
                            color: _hasResponded ? Colors.grey.shade400 : Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          'JE VAIS BIEN',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _hasResponded ? Colors.grey.shade400 : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Bouton J'AI BESOIN D'AIDE
                SizedBox(
                  width: double.infinity,
                  height: 68,
                  child: ElevatedButton(
                    onPressed: _hasResponded ? null : () => _respond(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasResponded ? Colors.grey : const Color(0xFFFF5F6D),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: _hasResponded ? 0 : 6,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sos, size: 30,
                            color: _hasResponded ? Colors.grey.shade400 : Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          "J'AI BESOIN D'AIDE",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: _hasResponded ? Colors.grey.shade400 : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}