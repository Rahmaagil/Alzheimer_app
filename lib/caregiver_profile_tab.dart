import 'package:alzhecare/fcm_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sign_in_screen.dart';
import 'caregiver_settings_screen.dart';
import 'user_session_manager.dart';
import 'geofencing_service.dart';
import 'patient_caregiver_link_service.dart';

class CaregiverProfileTab extends StatefulWidget {
  const CaregiverProfileTab({super.key});

  @override
  State<CaregiverProfileTab> createState() => _CaregiverProfileTabState();
}

class _CaregiverProfileTabState extends State<CaregiverProfileTab> {
  Map<String, dynamic>? _patientData;
  List<String> _linkedPatientUids = [];
  bool _isLoading = true;

  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _doctorCtrl = TextEditingController();
  final _treatmentCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _homeAddressCtrl = TextEditingController();
  final _diabetesCtrl = TextEditingController();
  final _bloodPressureCtrl = TextEditingController();
  final _otherConditionsCtrl = TextEditingController();

  String _diseaseStage = 'Léger';
  final List<String> _stages = ['Léger', 'Modéré', 'Avancé'];
  String? _currentPatientUid;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _doctorCtrl.dispose();
    _treatmentCtrl.dispose();
    _allergiesCtrl.dispose();
    _homeAddressCtrl.dispose();
    _diabetesCtrl.dispose();
    _bloodPressureCtrl.dispose();
    _otherConditionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
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

      final linkedPatients = List<String>.from(
          suiveurDoc.data()?['linkedPatients'] ?? []
      );

      if (linkedPatients.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Aucun patient lié"),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          _linkedPatientUids = [];
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _linkedPatientUids = linkedPatients;
        _currentPatientUid = linkedPatients.first;
      });

      await _loadPatientData(linkedPatients.first);

    } catch (e) {
      debugPrint("Erreur: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPatientData(String patientUid) async {
    try {
      final patDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .get();

      if (!patDoc.exists) {
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

      final data = patDoc.data();

      setState(() {
        _currentPatientUid = patientUid;
        _patientData = data;
        _nameCtrl.text = data?['name'] ?? '';
        _ageCtrl.text = data?['age']?.toString() ?? '';
        _doctorCtrl.text = data?['doctor'] ?? '';
        _treatmentCtrl.text = data?['treatment'] ?? '';
        _allergiesCtrl.text = data?['allergies'] ?? '';
        _homeAddressCtrl.text = data?['homeAddress'] ?? '';
        _diabetesCtrl.text = data?['diabetes'] ?? '';
        _bloodPressureCtrl.text = data?['bloodPressure'] ?? '';
        _otherConditionsCtrl.text = data?['otherConditions'] ?? '';
        _diseaseStage = data?['diseaseStage'] ?? 'Léger';
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Erreur: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateInviteCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final code = await PatientCaregiverLinkService.createInviteCode(
        caregiverUid: user.uid,
        expiryHours: 24,
      );

      if (mounted) Navigator.pop(context);

      if (code == null) {
        throw Exception('Erreur génération code');
      }

      _showCodeDialog(code);

    } catch (e) {
      if (mounted) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCodeDialog(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.qr_code_2,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Code d\'invitation',
                style: TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Partagez ce code avec votre proche',
              style: TextStyle(fontSize: 14, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A90E2).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.orange,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Expire dans 24h',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Code copié'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copier'),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _savePatientInfo() async {
    if (_currentPatientUid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentPatientUid)
          .update({
        'name': _nameCtrl.text.trim(),
        'age': int.tryParse(_ageCtrl.text.trim()),
        'doctor': _doctorCtrl.text.trim(),
        'treatment': _treatmentCtrl.text.trim(),
        'allergies': _allergiesCtrl.text.trim(),
        'homeAddress': _homeAddressCtrl.text.trim(),
        'diabetes': _diabetesCtrl.text.trim(),
        'bloodPressure': _bloodPressureCtrl.text.trim(),
        'otherConditions': _otherConditionsCtrl.text.trim(),
        'diseaseStage': _diseaseStage,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour'),
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

  void _showEditDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEAF2FF), Color(0xFFF6FBFF)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Center(
                  child: Text(
                    'Modifier les informations',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E5AAC),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                _field(_nameCtrl, 'Nom du patient', Icons.person_outline),
                const SizedBox(height: 14),
                _field(_ageCtrl, 'Age', Icons.cake_outlined,
                    type: TextInputType.number),
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  value: _diseaseStage,
                  items: _stages
                      .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s, style: const TextStyle(fontSize: 16)),
                  ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setSheetState(() => _diseaseStage = v);
                  },
                  decoration: InputDecoration(
                    labelText: 'Stade de la maladie',
                    labelStyle: const TextStyle(fontSize: 16),
                    prefixIcon: const Icon(
                      Icons.medical_information_outlined,
                      color: Color(0xFF4A90E2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                _field(_doctorCtrl, 'Medecin referent',
                    Icons.medical_services_outlined),
                const SizedBox(height: 14),
                _field(_treatmentCtrl, 'Traitement', Icons.medication_outlined),
                const SizedBox(height: 14),
                _field(_allergiesCtrl, 'Allergies', Icons.warning_amber_outlined),
                const SizedBox(height: 14),
                _field(_diabetesCtrl, 'Diabete', Icons.bloodtype_outlined),
                const SizedBox(height: 14),
                _field(_bloodPressureCtrl, 'Tension arterielle',
                    Icons.favorite_outline),
                const SizedBox(height: 14),
                _field(_otherConditionsCtrl, 'Autres conditions',
                    Icons.health_and_safety_outlined),
                const SizedBox(height: 14),
                _field(_homeAddressCtrl, 'Adresse du domicile',
                    Icons.home_outlined),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _savePatientInfo();
                    },
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
                          colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(30)),
                      ),
                      child: const Center(
                        child: Text(
                          'Enregistrer',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
      TextEditingController ctrl,
      String hint,
      IconData icon, {
        TextInputType? type,
      }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(fontSize: 16),
        prefixIcon: Icon(icon, color: const Color(0xFF4A90E2)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Déconnexion"),
        content: const Text("Voulez-vous vraiment vous déconnecter ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E5AAC),
            ),
            child: const Text("Déconnexion", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FCMService.stopListeningFirestoreAlerts();
      await GeofencingService.stopTracking();
      await UserSessionManager.clearSession();
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SignInScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      print("[Logout] Erreur: $e");
    }
  }

  void _showRemindersManagement() {
    if (_currentPatientUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Aucun patient lié"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _RemindersManagementScreen(patientUid: _currentPatientUid!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        title: const Text(
          'Profil',
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
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
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
                child: const Icon(Icons.person, color: Colors.white, size: 45),
              ),

              const SizedBox(height: 16),

              Text(
                _patientData?['name'] ?? 'Patient',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E5AAC),
                ),
              ),

              const SizedBox(height: 30),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: _generateInviteCode,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4A90E2).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.qr_code_2,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Générer un code',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Pour inviter un proche',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (_patientData != null)
                _card(
                  'Informations du patient',
                  action: _buildGradientButton('Modifier', _showEditDialog),
                  child: Column(
                    children: [
                      if ((_patientData?['age'] ?? 0) > 0)
                        _infoRow(Icons.cake_outlined, 'Âge', '${_patientData!['age']} ans'),
                      if ((_patientData?['diseaseStage'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(Icons.medical_information_outlined, 'Stade', _patientData!['diseaseStage']),
                      ],
                      if ((_patientData?['doctor'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(Icons.medical_services_outlined, 'Médecin', _patientData!['doctor']),
                      ],
                      if ((_patientData?['treatment'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(Icons.medication_outlined, 'Traitement', _patientData!['treatment']),
                      ],
                      if ((_patientData?['allergies'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(Icons.warning_amber_outlined, 'Allergies', _patientData!['allergies']),
                      ],
                      if ((_patientData?['diabetes'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(Icons.bloodtype_outlined, 'Diabète', _patientData!['diabetes']),
                      ],
                      if ((_patientData?['bloodPressure'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(Icons.favorite_outline, 'Tension', _patientData!['bloodPressure']),
                      ],
                      if ((_patientData?['otherConditions'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(Icons.health_and_safety_outlined, 'Autres', _patientData!['otherConditions']),
                      ],
                      if ((_patientData?['homeAddress'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _infoRow(Icons.home_outlined, 'Domicile', _patientData!['homeAddress']),
                      ],
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              _card(
                'Paramètres',
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CaregiverSettingsScreen()),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.settings, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Zone de sécurité',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2E5AAC),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Domicile, rayon',
                                    style: TextStyle(fontSize: 14, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, color: Colors.black26, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    InkWell(
                      onTap: _showRemindersManagement,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.notifications, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Gérer les rappels',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2E5AAC),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Ajouter, modifier, supprimer',
                                    style: TextStyle(fontSize: 14, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, color: Colors.black26, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF5F6D),
                    side: const BorderSide(color: Color(0xFFFF5F6D), width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  icon: const Icon(Icons.logout, size: 22),
                  label: const Text(
                    'Se déconnecter',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(String title, {required Widget child, Widget? action}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E5AAC),
              ),
            ),
            if (action != null) action,
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );

  Widget _infoRow(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, color: const Color(0xFF4A90E2), size: 18),
      const SizedBox(width: 8),
      Text('$label : ', style: const TextStyle(fontSize: 15, color: Colors.black45)),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF2E5AAC),
          ),
        ),
      ),
    ],
  );

  Widget _buildGradientButton(String text, VoidCallback onPressed) => SizedBox(
    height: 36,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
          ),
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// ==================== ÉCRAN DE GESTION DES RAPPELS ====================

class _RemindersManagementScreen extends StatefulWidget {
  final String patientUid;

  const _RemindersManagementScreen({required this.patientUid});

  @override
  State<_RemindersManagementScreen> createState() => _RemindersManagementScreenState();
}

class _RemindersManagementScreenState extends State<_RemindersManagementScreen> {
  List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  // -------- LECTURE DES RAPPELS (firestore/rappels) --------
  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientUid)
          .collection('rappels')        // <-- IMPORTANT
          .orderBy('timestamp')         // <-- le vrai timestamp
          .get();

      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['nom'] ?? '',          // <-- nom = titre
          'date': data['timestamp'],           // <-- timestamp = date
          'type': data['type'] ?? '',
        };
      }).toList();

      setState(() {
        _reminders = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Erreur: $e");
      setState(() => _isLoading = false);
    }
  }

  // -------- SUPPRESSION --------
  Future<void> _deleteReminder(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Supprimer ce rappel ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Non"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Oui", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientUid)
          .collection('rappels')     // <-- IMPORTANT
          .doc(docId)
          .delete();

      _loadReminders();
    } catch (e) {
      debugPrint("Erreur: $e");
    }
  }

  // -------- AJOUT D’UN RAPPEL --------
  void _showAddDialog() {
    final titleController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFF0F7FF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text(
              'Nouveau rappel',
              style: TextStyle(
                color: Color(0xFF2E5AAC),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    labelText: 'Quoi ?',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) setDialogState(() => selectedDate = date);
                        },
                        child: _buildDateBox(selectedDate),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (time != null) setDialogState(() => selectedTime = time);
                        },
                        child: _buildTimeBox(selectedTime),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Annuler", style: TextStyle(fontSize: 16)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Entrez un titre")),
                    );
                    return;
                  }

                  final reminderDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.patientUid)
                      .collection('rappels')    // <-- IMPORTANT
                      .add({
                    'nom': title,
                    'type': 'general',                    // optionnel
                    'timestamp': Timestamp.fromDate(reminderDateTime),
                  });

                  Navigator.pop(dialogContext);
                  _loadReminders();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Rappel ajouté"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Ajouter", style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }

  // --- Helpers d'affichage ---
  Widget _buildDateBox(DateTime d) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4A90E2), width: 2),
      ),
      child: Column(
        children: [
          const Icon(Icons.calendar_today, color: Color(0xFF4A90E2), size: 28),
          const SizedBox(height: 8),
          Text("${d.day}/${d.month}",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E5AAC))),
        ],
      ),
    );
  }

  Widget _buildTimeBox(TimeOfDay t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4A90E2), width: 2),
      ),
      child: Column(
        children: [
          const Icon(Icons.access_time, color: Color(0xFF4A90E2), size: 28),
          const SizedBox(height: 8),
          Text(t.format(context),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2E5AAC))),
        ],
      ),
    );
  }

  // -------- FORMATAGE --------
  String _formatTime(Timestamp? ts) {
    if (ts == null) return '--:--';
    final d = ts.toDate();
    return "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '--/--/----';
    final d = ts.toDate();
    return "${d.day}/${d.month}/${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        title: const Text(
          "Rappels du patient",
          style: TextStyle(
            color: Color(0xFF2E5AAC),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)]),
          borderRadius: BorderRadius.circular(30),
        ),
        child: FloatingActionButton.extended(
          onPressed: _showAddDialog,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add, color: Colors.white, size: 28),
          label: const Text("Ajouter",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)))
          : _reminders.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _loadReminders,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: _reminders.map((r) => _buildReminderCard(r)).toList(),
        ),
      ),
    );
  }

  // -------- AFFICHAGE D’UNE CARTE --------
  Widget _buildReminderCard(Map<String, dynamic> reminder) {
    final title = reminder['title'] as String;
    final ts = reminder['date'] as Timestamp?;
    final docId = reminder['id'] as String;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.notifications, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(_formatDate(ts), style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(_formatTime(ts), style: TextStyle(fontSize: 16, color: Colors.grey[700])),
                  ],
                ),
              ]),
            ),

            InkWell(
              onTap: () => _deleteReminder(docId),
              child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 30),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 30),
          const Text(
            "Aucun rappel",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF2E5AAC)),
          ),
          const SizedBox(height: 16),
          Text("Appuyez sur + pour ajouter",
              style: TextStyle(fontSize: 18, color: Colors.grey[700])),
        ],
      ),
    );
  }
}