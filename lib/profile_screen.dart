import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          _profileData = doc.data();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2E5AAC)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Mon Profil",
          style: TextStyle(
            color: Color(0xFF2E5AAC),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
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
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadProfile,
            color: const Color(0xFF4A90E2),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // Avatar
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    _profileData?['name'] ?? "Mon nom",
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E5AAC),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 30),

                  // Section informations generales
                  _buildSectionCard(
                    'Informations generales',
                    Icons.person_outline,
                    [
                      if ((_profileData?['age'] ?? 0) > 0)
                        _buildInfoRow(
                          Icons.cake_outlined,
                          'Age',
                          '${_profileData!['age']} ans',
                          const Color(0xFF66BB6A),
                        ),
                      if ((_profileData?['diseaseStage'] ?? '').toString().isNotEmpty)
                        _buildInfoRow(
                          Icons.medical_information_outlined,
                          'Stade de la maladie',
                          _profileData!['diseaseStage'],
                          const Color(0xFF4A90E2),
                        ),
                      if ((_profileData?['homeAddress'] ?? '').toString().isNotEmpty)
                        _buildInfoRow(
                          Icons.home_outlined,
                          'Domicile',
                          _profileData!['homeAddress'],
                          const Color(0xFFFFB74D),
                        ),
                      if ((_profileData?['caregiverPhone'] ?? '').toString().isNotEmpty)
                        _buildInfoRow(
                          Icons.phone_outlined,
                          'Telephone proche',
                          _profileData!['caregiverPhone'],
                          const Color(0xFF66BB6A),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Section informations medicales
                  _buildSectionCard(
                    'Informations medicales',
                    Icons.medical_services_outlined,
                    [
                      if ((_profileData?['doctor'] ?? '').toString().isNotEmpty)
                        _buildInfoRow(
                          Icons.medical_services_outlined,
                          'Medecin referent',
                          _profileData!['doctor'],
                          const Color(0xFF4A90E2),
                        ),
                      if ((_profileData?['treatment'] ?? '').toString().isNotEmpty)
                        _buildInfoRow(
                          Icons.medication_outlined,
                          'Traitement',
                          _profileData!['treatment'],
                          const Color(0xFFFF6B6B),
                        ),
                      if ((_profileData?['allergies'] ?? '').toString().isNotEmpty)
                        _buildInfoRow(
                          Icons.warning_amber_outlined,
                          'Allergies',
                          _profileData!['allergies'],
                          const Color(0xFFFF9800),
                        ),
                    ],
                  ),

                  // Section autres conditions (affiche seulement si au moins 1 champ rempli)
                  if ((_profileData?['diabetes'] ?? '').toString().isNotEmpty ||
                      (_profileData?['bloodPressure'] ?? '').toString().isNotEmpty ||
                      (_profileData?['otherConditions'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      'Autres conditions',
                      Icons.health_and_safety_outlined,
                      [
                        if ((_profileData?['diabetes'] ?? '').toString().isNotEmpty)
                          _buildInfoRow(
                            Icons.bloodtype_outlined,
                            'Diabete',
                            _profileData!['diabetes'],
                            const Color(0xFF9C27B0),
                          ),
                        if ((_profileData?['bloodPressure'] ?? '').toString().isNotEmpty)
                          _buildInfoRow(
                            Icons.favorite_outline,
                            'Tension arterielle',
                            _profileData!['bloodPressure'],
                            const Color(0xFFE91E63),
                          ),
                        if ((_profileData?['otherConditions'] ?? '').toString().isNotEmpty)
                          _buildInfoRow(
                            Icons.health_and_safety_outlined,
                            'Autres',
                            _profileData!['otherConditions'],
                            const Color(0xFF4A90E2),
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 30),

                  // Message info
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF4A90E2).withValues(alpha: 0.15),
                          const Color(0xFF6EC6FF).withValues(alpha: 0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF4A90E2),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF4A90E2),
                          size: 28,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            "Votre proche peut modifier ces informations",
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[800],
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    // Ne pas afficher la section si aucun enfant
    if (children.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF4A90E2), size: 24),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E5AAC),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children.map((child) {
            final index = children.indexOf(child);
            return Column(
              children: [
                if (index > 0) const SizedBox(height: 12),
                child,
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E5AAC),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}