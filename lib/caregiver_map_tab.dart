import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:ui' as ui;
import 'dart:async';

class CaregiverMapTab extends StatefulWidget {
  const CaregiverMapTab({super.key});
  @override
  State<CaregiverMapTab> createState() => _CaregiverMapTabState();
}

class _CaregiverMapTabState extends State<CaregiverMapTab> {
  Map<String, dynamic>? _lastPosition;
  String? _patientName;
  String? _patientUid;
  bool _isLoading = true;
  double _safetyRadius = 300;
  final MapController _mapController = MapController();

  StreamSubscription<DocumentSnapshot>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _initializeRealtimeTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  /// Initialise le suivi en temps réel
  Future<void> _initializeRealtimeTracking() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // MODIFIE: Récupérer liste patients liés
      final suiveurDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final linkedPatients = List<String>.from(
          suiveurDoc.data()?['linkedPatients'] ?? []
      );

      if (linkedPatients.isEmpty) {
        debugPrint('[Map] Aucun patient lié');
        setState(() => _isLoading = false);
        return;
      }

      // Afficher le PREMIER patient de la liste
      final patientUid = linkedPatients.first;
      _patientUid = patientUid;

      debugPrint('[Map] Affichage patient: $patientUid');

      // Récupérer le nom du patient
      final patientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .get();

      _patientName = patientDoc.data()?['name'] ?? 'Patient';
      _safetyRadius = (patientDoc.data()?['safeZoneRadius'] ?? 300).toDouble();

      // ECOUTE EN TEMPS REEL de la position
      _positionSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .snapshots()
          .listen((snapshot) {
        if (!snapshot.exists || !mounted) return;

        final data = snapshot.data();
        final newPosition = data?['lastPosition'];

        if (newPosition != null) {
          setState(() {
            _lastPosition = newPosition;
            _isLoading = false;
          });

          debugPrint("[Map] Position mise à jour: "
              "${newPosition['latitude']}, ${newPosition['longitude']}");

          // Auto-recentrer si c'est la première position
          if (_lastPosition != null && _isLoading) {
            _centerOnPatient();
          }
        }
      });

      setState(() => _isLoading = false);

    } catch (e) {
      debugPrint("[Map] Erreur initialisation: $e");
      setState(() => _isLoading = false);
    }
  }

  void _centerOnPatient() {
    if (_lastPosition != null) {
      final latLng = LatLng(
        _lastPosition!['latitude'] as double,
        _lastPosition!['longitude'] as double,
      );
      _mapController.move(latLng, 15.0);
    }
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return 'Il y a ${diff.inDays}j';
  }

  @override
  Widget build(BuildContext context) {
    final hasPosition = _lastPosition != null;
    final patientLatLng = hasPosition
        ? LatLng(
      _lastPosition!['latitude'] as double,
      _lastPosition!['longitude'] as double,
    )
        : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Carte',
              style: TextStyle(
                color: Color(0xFF2E5AAC),
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            if (hasPosition) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF4CAF50),
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF2E5AAC)),
            tooltip: "Actualiser",
            onPressed: _centerOnPatient,
          ),
        ],
      ),
      body: _isLoading
          ? Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF2FF), Color(0xFFF6FBFF)],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
        ),
      )
          : !hasPosition
          ? _noPositionWidget()
          : Stack(
        children: [
          // CARTE
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: patientLatLng!,
              initialZoom: 15.0,
              minZoom: 5.0,
              maxZoom: 19.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.alzhecare.app',
              ),

              // Zone de sécurité
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: patientLatLng,
                    radius: _safetyRadius,
                    useRadiusInMeter: true,
                    color: const Color(0xFF4A90E2).withValues(alpha: 0.25),
                    borderColor: const Color(0xFF4A90E2),
                    borderStrokeWidth: 3.0,
                  ),
                ],
              ),

              // Marqueur patient
              MarkerLayer(
                markers: [
                  Marker(
                    point: patientLatLng,
                    width: 60,
                    height: 70,
                    child: Column(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                            ),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4A90E2).withValues(alpha: 0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        CustomPaint(
                          size: const Size(12, 8),
                          painter: _MarkerPainter(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // INFO EN HAUT
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                      ),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _patientName ?? '--',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E5AAC),
                          ),
                        ),
                        Text(
                          _timeAgo(_lastPosition?['updatedAt']),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF81C784), Color(0xFF66BB6A)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        const Text(
                          'En temps réel',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // SLIDER RAYON ZONE
          Positioned(
            bottom: 80,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.radio_button_unchecked,
                        color: Color(0xFF4A90E2),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Zone de sécurité : ${_safetyRadius.toInt()} m',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E5AAC),
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF4A90E2),
                      inactiveTrackColor: const Color(0xFF4A90E2).withValues(alpha: 0.3),
                      thumbColor: const Color(0xFF4A90E2),
                      overlayColor: const Color(0xFF4A90E2).withValues(alpha: 0.2),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: _safetyRadius,
                      min: 50,
                      max: 1000,
                      divisions: 19,
                      onChanged: (v) => setState(() => _safetyRadius = v),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // BOUTON RECENTRER
          Positioned(
            bottom: 16,
            left: 12,
            right: 12,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _centerOnPatient,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                ),
                child: Ink(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF7FB3FF), Color(0xFF2EC7F0)],
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(30)),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.my_location, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'Recentrer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noPositionWidget() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF2FF), Color(0xFFF6FBFF)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(Icons.location_off, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              const Text(
                'Position inconnue',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E5AAC),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Le patient n\'a pas encore partagé\nsa position GPS.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              const Text(
                'Le suivi en temps réel est actif.\nLa position apparaîtra automatiquement.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4A90E2),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF4A90E2);
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}