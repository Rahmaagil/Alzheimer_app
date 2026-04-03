import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'dart:math' as math;

class FindHomeScreen extends StatefulWidget {
  const FindHomeScreen({super.key});

  @override
  State<FindHomeScreen> createState() => _FindHomeScreenState();
}

class _FindHomeScreenState extends State<FindHomeScreen> {
  bool _isLoading = false;
  bool _isNavigating = false;
  String? _errorMessage;
  String? _homeAddress;
  Position? _currentPosition;
  double? _homeLat;
  double? _homeLng;
  double? _distanceMeters;
  double? _bearing;

  StreamSubscription<Position>? _positionStream;
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadHomeAddress();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("fr-FR");
    await _tts.setSpeechRate(0.4);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  Future<void> _loadHomeAddress() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final homeLocation = doc.data()?['homeLocation'];

      setState(() {
        _homeAddress = doc.data()?['homeAddress'];
        if (homeLocation != null) {
          _homeLat = homeLocation['latitude']?.toDouble();
          _homeLng = homeLocation['longitude']?.toDouble();
        }
      });
    } catch (e) {
      debugPrint('Erreur load home: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Permission GPS refusée.';
            _isLoading = false;
          });
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (_homeLat == null || _homeLng == null) {
        setState(() {
          _errorMessage = 'Votre adresse domicile n\'est pas configurée.\nDemandez à votre proche de la définir.';
          _isLoading = false;
        });
        return;
      }

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        _homeLat!,
        _homeLng!,
      );

      final bearing = Geolocator.bearingBetween(
        position.latitude,
        position.longitude,
        _homeLat!,
        _homeLng!,
      );

      setState(() {
        _currentPosition = position;
        _distanceMeters = distance;
        _bearing = bearing;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  void _startGuidance() {
    if (_homeLat == null || _homeLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adresse domicile non configurée'),
          backgroundColor: Color(0xFFFF5F6D),
        ),
      );
      return;
    }

    setState(() => _isNavigating = true);

    _speak("Guidage activé. Je vais vous guider vers votre domicile.");

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Mise à jour tous les 10 mètres
      ),
    ).listen((Position position) {
      _updateGuidance(position);
    });
  }

  void _stopGuidance() {
    _positionStream?.cancel();
    _tts.stop();
    setState(() => _isNavigating = false);
    _speak("Guidage arrêté");
  }

  void _updateGuidance(Position position) {
    if (_homeLat == null || _homeLng == null) return;

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _homeLat!,
      _homeLng!,
    );

    final bearing = Geolocator.bearingBetween(
      position.latitude,
      position.longitude,
      _homeLat!,
      _homeLng!,
    );

    setState(() {
      _currentPosition = position;
      _distanceMeters = distance;
      _bearing = bearing;
    });

    // Guidance vocale
    if (distance < 50) {
      _speak("Vous êtes presque arrivé. Encore ${distance.toInt()} mètres.");
    } else if (distance < 100) {
      _speak("Continuez tout droit. Encore ${distance.toInt()} mètres.");
    }

    // Arrivé
    if (distance < 20) {
      _speak("Vous êtes arrivé à votre domicile!");
      _stopGuidance();
    }
  }

  String _getDirection() {
    if (_bearing == null) return "—";

    final angle = _bearing!;

    if (angle >= -22.5 && angle < 22.5) return "Tout droit";
    if (angle >= 22.5 && angle < 67.5) return "Légèrement à droite";
    if (angle >= 67.5 && angle < 112.5) return "À droite";
    if (angle >= 112.5 && angle < 157.5) return "Derrière droite";
    if (angle >= 157.5 || angle < -157.5) return "Demi-tour";
    if (angle >= -157.5 && angle < -112.5) return "Derrière gauche";
    if (angle >= -112.5 && angle < -67.5) return "À gauche";
    if (angle >= -67.5 && angle < -22.5) return "Légèrement à gauche";

    return "—";
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toInt()} mètres';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2E5AAC)),
          onPressed: () {
            _stopGuidance();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Trouver mon domicile',
          style: TextStyle(
            color: Color(0xFF2E5AAC),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF2FF), Color(0xFFF6FBFF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                children: [
                  // ICONE
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7FB3FF), Color(0xFF2EC7F0)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2EC7F0).withOpacity(0.3),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.home, color: Colors.white, size: 50),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Rentrer chez moi",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E5AAC),
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    "Je vais vous guider jusqu'à votre domicile.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),

                  const SizedBox(height: 35),

                  // ADRESSE
                  if (_homeAddress != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.home_outlined, color: Color(0xFF4A90E2), size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Mon domicile', style: TextStyle(fontSize: 14, color: Colors.black54)),
                                const SizedBox(height: 4),
                                Text(_homeAddress!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2E5AAC))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // DIRECTION ET DISTANCE (MODE NAVIGATION)
                  if (_isNavigating && _distanceMeters != null) ...[
                    // Direction
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7FB3FF), Color(0xFF2EC7F0)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2EC7F0).withOpacity(0.3),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            _getDirection(),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _formatDistance(_distanceMeters!),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Bouton ARRÊTER
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _stopGuidance,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                        ),
                        child: Ink(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFFFF5F6D), Color(0xFFFFC371)]),
                            borderRadius: BorderRadius.all(Radius.circular(30)),
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.stop, color: Colors.white, size: 24),
                                SizedBox(width: 10),
                                Text("Arrêter le guidage", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // DISTANCE (MODE NORMAL)
                  if (!_isNavigating && _distanceMeters != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF7FB3FF), Color(0xFF2EC7F0)]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2EC7F0).withOpacity(0.3),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.straighten, color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Distance estimée', style: TextStyle(fontSize: 14, color: Colors.white70)),
                                const SizedBox(height: 4),
                                Text(_formatDistance(_distanceMeters!), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ERREUR
                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF5F6D), Color(0xFFFF2E63)]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF2E63).withOpacity(0.3),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(_errorMessage!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 30),

                  // BOUTON CALCULER DISTANCE
                  if (!_isNavigating && _distanceMeters == null)
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _getCurrentLocation,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                        ),
                        child: Ink(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)]),
                            borderRadius: BorderRadius.all(Radius.circular(30)),
                          ),
                          child: Center(
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.my_location, color: Colors.white, size: 24),
                                SizedBox(width: 10),
                                Text("Calculer la distance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // BOUTON COMMENCER LE GUIDAGE
                  if (!_isNavigating && _distanceMeters != null)
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _startGuidance,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                        ),
                        child: Ink(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFF7FB3FF), Color(0xFF2EC7F0)]),
                            borderRadius: BorderRadius.all(Radius.circular(30)),
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.navigation, color: Colors.white, size: 24),
                                SizedBox(width: 10),
                                Text("Commencer le guidage", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // NOTE
                  if (_homeAddress == null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.3), width: 1.5),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFFFFB74D), size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Demandez à votre proche de configurer votre adresse dans les paramètres.',
                              style: TextStyle(fontSize: 14, color: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}