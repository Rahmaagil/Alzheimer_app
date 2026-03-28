import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'fall_detection_service.dart';

class PatientFallMonitorScreen extends StatefulWidget {
  const PatientFallMonitorScreen({Key? key}) : super(key: key);

  @override
  State<PatientFallMonitorScreen> createState() => _PatientFallMonitorScreenState();
}

class _PatientFallMonitorScreenState extends State<PatientFallMonitorScreen> {
  final FallDetectionService _fallService = FallDetectionService();
  bool _isMonitoring = false;
  bool _isInitializing = true;
  String _status = 'Initialisation...';

  @override
  void initState() {
    super.initState();
    _initializeFallDetection();
  }

  Future<void> _initializeFallDetection() async {
    try {
      await _fallService.initialize();

      _fallService.onFallDetected = (isFall, confidence) {
        if (isFall) {
          _handleFallDetected(confidence);
        }
      };

      setState(() {
        _isInitializing = false;
        _status = 'Prêt';
      });
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _status = 'Erreur: $e';
      });
      debugPrint('[PatientFallMonitor] Erreur init: $e');
    }
  }

  Future<void> _handleFallDetected(double confidence) async {
    debugPrint('[PatientFallMonitor] Chute detectee! Confiance: ${(confidence * 100).toStringAsFixed(1)}%');

    if (!mounted) return;

    // Montrer dialog de confirmation
    final shouldSendAlert = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _FallConfirmationDialog(),
    );

    // Si annule, ne rien faire
    if (shouldSendAlert == false) {
      debugPrint('[PatientFallMonitor] Alerte annulee par patient');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Alerte annulee'),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    // Sinon, envoyer alerte
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // NOUVEAU: Liste
      final linkedCaregivers = List<String>.from(
          userDoc.data()?['linkedCaregivers'] ?? []
      );

      if (linkedCaregivers.isEmpty) {
        debugPrint('[PatientFallMonitor] Aucun proche lié');
        return;
      }

      // Récupérer position GPS
      GeoPoint? location;
      final locationDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('locations')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (locationDoc.docs.isNotEmpty) {
        location = locationDoc.docs.first.data()['location'] as GeoPoint?;
      }

      // ENVOYER A TOUS LES SUIVEURS
      for (final caregiverId in linkedCaregivers) {
        await FirebaseFirestore.instance
            .collection('notifications')
            .add({
          'caregiverId': caregiverId,
          'patientId': user.uid,
          'type': 'fall',
          'title': 'Alerte Chute Detectee',
          'message': 'Une chute a ete detectee avec ${(confidence * 100).toStringAsFixed(0)}% de confiance',
          'location': location,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
          'confidence': confidence,
          'confirmed': shouldSendAlert == true ? 'patient' : 'auto',
          'latitude': location?.latitude,
          'longitude': location?.longitude,
        });
      }

      debugPrint('[PatientFallMonitor] Alerte envoyée à ${linkedCaregivers.length} proche(s)');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Alerte chute envoyee a ${linkedCaregivers.length} proche(s)'),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('[PatientFallMonitor] Erreur envoi alerte: $e');
    }
  }

  void _toggleMonitoring() {
    setState(() {
      if (_isMonitoring) {
        _fallService.stopMonitoring();
        _status = 'Surveillance arretee';
      } else {
        _fallService.startMonitoring();
        _status = 'Surveillance active';
      }
      _isMonitoring = !_isMonitoring;
    });
  }

  @override
  void dispose() {
    _fallService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF2FF), Color(0xFFF6FBFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Detection de Chute',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3142),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icone status
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _isMonitoring
                                ? [Color(0xFF81C784), Color(0xFF66BB6A)]
                                : [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isMonitoring ? Icons.sensors : Icons.sensors_off,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),

                      SizedBox(height: 32),

                      // Status
                      Text(
                        _status,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3142),
                        ),
                      ),

                      SizedBox(height: 48),

                      // Bouton toggle
                      if (!_isInitializing)
                        ElevatedButton(
                          onPressed: _toggleMonitoring,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _isMonitoring
                                    ? [Color(0xFFFF5F6D), Color(0xFFFFC371)]
                                    : [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 15,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isMonitoring ? Icons.stop : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  _isMonitoring ? 'Arreter' : 'Demarrer',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (_isInitializing)
                        CircularProgressIndicator(),

                      SizedBox(height: 32),

                      // Info
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 40),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFF4A90E2),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'La surveillance detecte automatiquement les chutes. Vous aurez 30 secondes pour confirmer.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF2D3142),
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}

// Widget de confirmation
class _FallConfirmationDialog extends StatefulWidget {
  @override
  State<_FallConfirmationDialog> createState() => _FallConfirmationDialogState();
}

class _FallConfirmationDialogState extends State<_FallConfirmationDialog> {
  int _secondsRemaining = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _secondsRemaining--;
      });

      if (_secondsRemaining <= 0) {
        timer.cancel();
        Navigator.pop(context, true); // Timeout -> Envoyer alerte
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icone animee
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFF5F6D), Color(0xFFFF2E63)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFFF5F6D).withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 45,
                color: Colors.white,
              ),
            ),

            SizedBox(height: 24),

            // Titre
            Text(
              'Chute Detectee!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD32F2F),
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 12),

            // Compte a rebours
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Text(
                'Alerte dans $_secondsRemaining secondes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD32F2F),
                ),
              ),
            ),

            SizedBox(height: 24),

            // Message
            Text(
              'Allez-vous bien?',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 24),

            // Bouton "Je vais bien"
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, false); // Annuler alerte
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF43A047).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Je vais bien',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 12),

            // Bouton "Besoin d'aide"
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, true); // Envoyer alerte
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF5F6D), Color(0xFFFF2E63)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFFF5F6D).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sos, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        "J'ai besoin d'aide",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}