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
  final _addressController = TextEditingController();

  String? _patientUid;
  String? _homeAddress;
  double? _homeLat;
  double? _homeLng;
  int _safeZoneRadius = 300;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isGeocoding = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final suiveurDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final linkedPatientsRaw = suiveurDoc.data()?['linkedPatients'];
      List<String> linkedPatients = [];
      if (linkedPatientsRaw is List) {
        linkedPatients = linkedPatientsRaw
            .where((id) => id != null && id.toString().isNotEmpty)
            .map((id) => id.toString())
            .toList();
      }

      if (linkedPatients.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Aucun patient lié"), backgroundColor: Colors.orange),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final patientUid = linkedPatients.first;
      _patientUid = patientUid;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final homeAddress = data?['homeAddress'];
        final homeLocation = data?['homeLocation'];

        setState(() {
          _homeAddress = homeAddress;
          _addressController.text = homeAddress ?? '';
          if (homeLocation != null && homeLocation is Map) {
            _homeLat = homeLocation['latitude']?.toDouble();
            _homeLng = homeLocation['longitude']?.toDouble();
          }
          _safeZoneRadius = data?['safeZoneRadius'] ?? 300;
        });
      }
    } catch (e) {
      debugPrint('[Settings] Erreur: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _geocodeAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer une adresse'), backgroundColor: Colors.orange),
      );
      return false;
    }

    setState(() => _isGeocoding = true);

    try {
      List<Location> locations = await locationFromAddress(address);

      if (locations.isEmpty) {
        locations = await locationFromAddress('$address, Tunisia');
      }
      if (locations.isEmpty) {
        locations = await locationFromAddress('$address, Mahdia, Tunisia');
      }

      if (locations.isEmpty) {
        throw Exception('Aucune coordonnée trouvée');
      }

      final location = locations.first;

      setState(() {
        _homeAddress = address;
        _homeLat = location.latitude;
        _homeLng = location.longitude;
        _isGeocoding = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Coordonnées trouvées : ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
      return true;
    } catch (e) {
      setState(() => _isGeocoding = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Adresse introuvable. Essayez avec plus de détails.'), backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  Future<void> _saveSettings() async {
    if (_patientUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun patient lié')));
      return;
    }

    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer une adresse'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (address != _homeAddress || _homeLat == null || _homeLng == null) {
      final success = await _geocodeAddress();
      if (!success) return;
    }

    if (_homeLat == null || _homeLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coordonnées GPS manquantes'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(_patientUid!).update({
        'homeAddress': address,
        'homeLocation': {'latitude': _homeLat!, 'longitude': _homeLng!},
        'safeZoneRadius': _safeZoneRadius,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paramètres enregistrés avec succès!'), backgroundColor: Color(0xFF4CAF50)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
          'Paramètres du patient',
          style: TextStyle(color: Color(0xFF2E5AAC), fontWeight: FontWeight.bold, fontSize: 22),
        ),
        centerTitle: true,
      ),
      body: Container(
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
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)]),
                        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 20)],
                      ),
                      child: const Icon(Icons.settings, color: Colors.white, size: 45),
                    ),
                  ),
                  const SizedBox(height: 28),

                  _buildCardSection(
                    title: 'Domicile du patient',
                    icon: Icons.home,
                    iconGradient: const LinearGradient(colors: [Color(0xFF7FB3FF), Color(0xFF2EC7F0)]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_homeAddress != null && _homeLat != null && _homeLng != null)
                          ...[
                            const Text('Adresse enregistrée:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)]),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, color: Color(0xFF2EC7F0), size: 24),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(_homeAddress!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2E5AAC)))),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'GPS: ${_homeLat!.toStringAsFixed(6)}, ${_homeLng!.toStringAsFixed(6)}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                        TextField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: 'Entrer l\'adresse complète',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: const Icon(Icons.edit_location, color: Color(0xFF4A90E2)),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),

                        // Bouton "Trouver les coordonnées GPS" - Même style que "Enregistrer"
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isGeocoding ? null : _geocodeAddress,
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
                                child: _isGeocoding
                                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                    : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.my_location, color: Colors.white),
                                    SizedBox(width: 10),
                                    Text(
                                      'Trouver les coordonnées GPS',
                                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline, color: Color(0xFFFFB74D), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cliquez sur "Trouver les coordonnées GPS" avant de sauvegarder.',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildCardSection(
                    title: 'Zone de sécurité',
                    icon: Icons.radio_button_unchecked,
                    iconGradient: const LinearGradient(colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Rayon actuel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)]),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('$_safeZoneRadius m', style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Slider(
                          value: _safeZoneRadius.toDouble(),
                          min: 50,
                          max: 1000,
                          divisions: 19,
                          label: '$_safeZoneRadius m',
                          onChanged: (val) => setState(() => _safeZoneRadius = val.round()),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Bouton Enregistrer les modifications (inchangé)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                      ),
                      child: Ink(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)]),
                          borderRadius: BorderRadius.all(Radius.circular(30)),
                        ),
                        child: Center(
                          child: _isSaving
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save, color: Colors.white),
                              SizedBox(width: 10),
                              Text(
                                'Enregistrer les modifications',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
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

  Widget _buildCardSection({
    required String title,
    required IconData icon,
    required Gradient iconGradient,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(gradient: iconGradient, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2E5AAC))),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}