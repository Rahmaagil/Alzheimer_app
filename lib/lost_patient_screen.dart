import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class LostPatientScreen extends StatefulWidget {
  const LostPatientScreen({super.key});

  @override
  State<LostPatientScreen> createState() => _LostPatientScreen();
}

class _LostPatientScreen extends State<LostPatientScreen> {
  bool _isSending = false;
  bool _sent = false;
  String? _errorMessage;

  Future<void> _sendLocation() async {
    setState(() {
      _isSending = true;
      _errorMessage = null;
      _sent = false;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Permission GPS refusée.';
            _isSending = false;
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'GPS désactivé. Activez-le dans les paramètres.';
          _isSending = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Sauvegarder alerte locale
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('alerts')
          .add({
        'type': 'perdu',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'en attente',
      });

      // Mettre à jour position
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'lastPosition': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });

      //  Récupérer liste suiveurs et envoyer notification
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final linkedCaregivers = List<String>.from(
          userDoc.data()?['linkedCaregivers'] ?? []
      );

      // ENVOYER NOTIFICATION A TOUS LES SUIVEURS
      for (final caregiverId in linkedCaregivers) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'caregiverId': caregiverId,
          'patientId': user.uid,
          'type': 'lost',
          'title': 'Patient perdu',
          'message': 'Le patient a signalé être perdu',
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
          'latitude': position.latitude,
          'longitude': position.longitude,
        });
      }

      debugPrint('[LostPatient] Alerte envoyée à ${linkedCaregivers.length} proche(s)');

      setState(() {
        _sent = true;
        _isSending = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isSending = false;
      });
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Je suis perdu',
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
            colors: [
              Color(0xFFEAF2FF),
              Color(0xFFF6FBFF),
            ],
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
                        colors: [
                          Color(0xFFFFB74D),
                          Color(0xFFFF7043),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF7043).withOpacity(0.3),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Pas de panique !",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E5AAC),
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    "Vos proches recevront votre position.",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 35),

                  // CARTE STATUT
                  if (_sent)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
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
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Position envoyée !\nVos proches ont été alertés.",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_errorMessage != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5F6D), Color(0xFFFF2E63)],
                        ),
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
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 30),

                  // BOUTON ENVOYER
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _sendLocation,
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
                            colors: [Color(0xFFFFB74D), Color(0xFFFF7043)],
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(30)),
                        ),
                        child: Center(
                          child: _isSending
                              ? const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_on,
                                  color: Colors.white, size: 24),
                              const SizedBox(width: 10),
                              Text(
                                _sent
                                    ? "Envoyer à nouveau"
                                    : "Envoyer ma position",
                                style: const TextStyle(
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