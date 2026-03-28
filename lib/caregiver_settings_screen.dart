import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';

class CaregiverSettingsScreen extends StatefulWidget {
  const CaregiverSettingsScreen({super.key});

  @override
  State<CaregiverSettingsScreen> createState() => _CaregiverSettingsScreenState();
}

class _CaregiverSettingsScreenState extends State<CaregiverSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _patientUid;
  String? _homeAddress;
  double? _homeLat;
  double? _homeLng;
  int _safeZoneRadius = 300;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
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
        // Pas de patient lié
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Aucun patient lié à ce compte"),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Afficher le PREMIER patient
      final patientUid = linkedPatients.first;
      _patientUid = patientUid;

      debugPrint('[Settings] Modification patient: $patientUid');

      // Charger les paramètres du patient lié
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Patient introuvable"),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final data = doc.data();
      if (data != null) {
        setState(() {
          _homeAddress = data['homeAddress'];
          final loc = data['homeLocation'];
          if (loc != null) {
            _homeLat = loc['latitude'];
            _homeLng = loc['longitude'];
          }
          _safeZoneRadius = data['safeZoneRadius'] ?? 300;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[Settings] Erreur: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_patientUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun patient lié')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_patientUid)
          .update({
        'homeAddress': _homeAddress,
        'homeLocation': _homeLat != null && _homeLng != null
            ? {'latitude': _homeLat, 'longitude': _homeLng}
            : null,
        'safeZoneRadius': _safeZoneRadius,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paramètres enregistrés'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _setHomeAddress(String address) async {
    if (address.trim().isEmpty) {
      setState(() {
        _homeAddress = null;
        _homeLat = null;
        _homeLng = null;
      });
      return;
    }

    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        setState(() {
          _homeAddress = address;
          _homeLat = loc.latitude;
          _homeLng = loc.longitude;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Adresse trouvée'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Adresse non trouvée')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
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
          'Paramètres',
          style: TextStyle(
            color: Color(0xFF2E5AAC),
            fontWeight: FontWeight.bold,
            fontSize: 22,
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)))
            : SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icône header
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.settings,
                        color: Colors.white,
                        size: 45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ADRESSE DOMICILE
                  _buildCardSection(
                    title: 'Domicile du patient',
                    icon: Icons.home,
                    iconGradient: const LinearGradient(
                      colors: [Color(0xFF7FB3FF), Color(0xFF2EC7F0)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_homeAddress != null) ...[
                          const Text(
                            'Adresse enregistrée :',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, color: Color(0xFF2EC7F0), size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _homeAddress!,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2E5AAC),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        TextFormField(
                          initialValue: _homeAddress,
                          decoration: InputDecoration(
                            labelText: 'Entrer l\'adresse',
                            labelStyle: const TextStyle(fontSize: 17),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            prefixIcon: const Icon(Icons.edit_location, color: Color(0xFF4A90E2), size: 26),
                          ),
                          style: const TextStyle(fontSize: 17),
                          onFieldSubmitted: _setHomeAddress,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Utilisée pour "Trouver mon domicile" et comme centre de la zone',
                          style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ZONE SÉCURISÉE
                  _buildCardSection(
                    title: 'Zone de sécurité',
                    icon: Icons.radio_button_unchecked,
                    iconGradient: const LinearGradient(
                      colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Rayon actuel',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$_safeZoneRadius m',
                                style: const TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFF4A90E2),
                            inactiveTrackColor: const Color(0xFF4A90E2).withOpacity(0.3),
                            thumbColor: const Color(0xFF4A90E2),
                            overlayColor: const Color(0xFF4A90E2).withOpacity(0.2),
                            trackHeight: 6,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
                          ),
                          child: Slider(
                            value: _safeZoneRadius.toDouble(),
                            min: 50,
                            max: 1000,
                            divisions: 19,
                            label: '$_safeZoneRadius m',
                            onChanged: (val) {
                              setState(() => _safeZoneRadius = val.round());
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('50 m', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey[600])),
                            Text('1000 m', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey[600])),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ce cercle sera visible sur la carte',
                          style: TextStyle(fontSize: 16, color: Colors.grey[700], height: 1.4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Bouton Sauvegarder
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                      ),
                      child: Ink(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(30)),
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save, color: Colors.white),
                              SizedBox(width: 10),
                              Text(
                                'Enregistrer les modifications',
                                style: TextStyle(
                                  fontSize: 17,
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

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardSection({
    required String title,
    required IconData icon,
    required Widget child,
    Color? iconColor,
    Gradient? iconGradient,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: iconGradient,
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E5AAC),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}