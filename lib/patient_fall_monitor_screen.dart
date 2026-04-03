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

class _PatientFallMonitorScreenState extends State<PatientFallMonitorScreen> with WidgetsBindingObserver {
  final FallDetectionService _fallService = FallDetectionService();
  bool _isMonitoring = false;
  bool _isInitializing = true;
  bool _isProcessingFall = false;
  String _status = 'Initialisation...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeFallDetection();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _fallService.isInitialized && !_isMonitoring) {
      _startMonitoring();
    }
  }

  Future<void> _initializeFallDetection() async {
    try {
      await _fallService.initialize();

      _fallService.onFallDetected = (isFall, confidence) {
        if (isFall && !_isProcessingFall && mounted) {
          _handleFallDetected(confidence);
        }
      };

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _status = 'Surveillance active';
        });
        _startMonitoring();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _status = 'Erreur: $e';
        });
      }
    }
  }

  void _startMonitoring() {
    if (_isMonitoring) return;
    _fallService.startMonitoring();
    if (mounted) {
      setState(() {
        _isMonitoring = true;
        _status = 'Surveillance active';
      });
    }
  }

  Future<void> _handleFallDetected(double confidence) async {
    if (_isProcessingFall || !mounted) return;

    setState(() => _isProcessingFall = true);

    try {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => _FallAlertScreen(),
        ),
      );

      if (!mounted) return;

      if (result == true) {
        await _sendFallAlert(confidence, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Vous allez bien'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Erreur
    } finally {
      if (mounted) {
        setState(() => _isProcessingFall = false);
      }
    }
  }

  Future<void> _sendFallAlert(double confidence, bool patientConfirmed) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final linkedCaregiversRaw = userDoc.data()?['linkedCaregivers'];

      List<String> linkedCaregivers = [];
      if (linkedCaregiversRaw is List) {
        linkedCaregivers = linkedCaregiversRaw
            .where((id) => id != null && id.toString().isNotEmpty)
            .map((id) => id.toString())
            .toList();
      }

      if (linkedCaregivers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucun proche lie'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

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
        // Ignorer erreur GPS
      }

      int sent = 0;
      for (final caregiverId in linkedCaregivers) {
        try {
          await FirebaseFirestore.instance.collection('notifications').add({
            'caregiverId': caregiverId,
            'patientId': user.uid,
            'type': 'fall',
            'title': 'Alerte Chute Detectee',
            'message': 'Chute detectee avec ${(confidence * 100).toStringAsFixed(0)}% de confiance',
            'location': location,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'pending',
            'confidence': confidence,
            'confirmed': patientConfirmed ? 'patient' : 'auto',
            'latitude': latitude,
            'longitude': longitude,
          });
          sent++;
        } catch (e) {
          // Ignorer erreur individuelle
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alerte envoyee a $sent proche(s)'),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Erreur globale
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEAF2FF), Color(0xFFF6FBFF)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Detection de Chute',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: _isMonitoring
                                  ? [const Color(0xFF81C784), const Color(0xFF66BB6A)]
                                  : [const Color(0xFF9E9E9E), const Color(0xFF757575)],
                            ),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8))],
                          ),
                          child: Icon(_isMonitoring ? Icons.sensors : Icons.sensors_off, size: 60, color: Colors.white),
                        ),
                        const SizedBox(height: 32),
                        Text(_status, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF2D3142))),
                        const SizedBox(height: 16),
                        if (_isMonitoring)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.check_circle, color: Color(0xFF66BB6A), size: 20),
                                SizedBox(width: 8),
                                Text('Vous etes protege', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF66BB6A))),
                              ],
                            ),
                          ),
                        if (_isInitializing) const CircularProgressIndicator(),
                        const SizedBox(height: 48),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
                          ),
                          child: Column(
                            children: const [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: Color(0xFF4A90E2)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text('Comment ca fonctionne?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Text(
                                '• Surveillance automatique permanente\n• En cas de chute: 30 secondes pour repondre\n• Pas de reponse = alerte automatique',
                                style: TextStyle(fontSize: 14, color: Color(0xFF2D3142), height: 1.5),
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
      ),
    );
  }
}

class _FallAlertScreen extends StatefulWidget {
  @override
  State<_FallAlertScreen> createState() => _FallAlertScreenState();
}

class _FallAlertScreenState extends State<_FallAlertScreen> {
  int _secondsRemaining = 30;
  Timer? _timer;
  bool _hasResponded = false;

  @override
  void initState() {
    super.initState();
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
        _respond(true);
      }
    });
  }

  void _respond(bool needHelp) {
    if (_hasResponded) return;
    setState(() => _hasResponded = true);
    _timer?.cancel();
    Navigator.of(context).pop(needHelp);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [Color(0xFFFF5F6D), Color(0xFFFF2E63)]),
                    boxShadow: [BoxShadow(color: const Color(0xFFFF5F6D).withOpacity(0.5), blurRadius: 30, spreadRadius: 10)],
                  ),
                  child: const Icon(Icons.warning_amber_rounded, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 40),
                const Text('Chute Detectee!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFD32F2F))),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    _hasResponded ? 'Traitement...' : '$_secondsRemaining secondes',
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFFD32F2F)),
                  ),
                ),
                const SizedBox(height: 40),
                const Text('Allez-vous bien?', style: TextStyle(fontSize: 24, color: Colors.black87)),
                const SizedBox(height: 60),
                SizedBox(
                  width: double.infinity,
                  height: 70,
                  child: ElevatedButton(
                    onPressed: _hasResponded ? null : () => _respond(false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasResponded ? Colors.grey : const Color(0xFF66BB6A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: _hasResponded ? 0 : 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 32, color: _hasResponded ? Colors.grey.shade600 : Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          'JE VAIS BIEN',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _hasResponded ? Colors.grey.shade600 : Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 70,
                  child: ElevatedButton(
                    onPressed: _hasResponded ? null : () => _respond(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _hasResponded ? Colors.grey : const Color(0xFFFF5F6D),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: _hasResponded ? 0 : 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sos, size: 32, color: _hasResponded ? Colors.grey.shade600 : Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          "J'AI BESOIN D'AIDE",
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _hasResponded ? Colors.grey.shade600 : Colors.white),
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