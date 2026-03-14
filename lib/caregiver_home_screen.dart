import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'background_service.dart';
import 'caregiver_alerts_screen.dart';
import 'caregiver_dashboard_tab.dart';
import 'caregiver_map_tab.dart';
import 'caregiver_profile_tab.dart';
import 'caregiver_chatbot_screen.dart';
import 'fcm_service.dart';

class CaregiverHomeScreen extends StatefulWidget {
  const CaregiverHomeScreen({super.key});

  @override
  State<CaregiverHomeScreen> createState() => _CaregiverHomeScreenState();
}

class _CaregiverHomeScreenState extends State<CaregiverHomeScreen> {
  int _currentIndex = 0;
  int _pendingAlerts = 0;

  @override
  void initState() {
    super.initState();
    _listenAlerts();
    _initializeFCM();
  }

  Future<void> _initializeFCM() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FCMService.startListeningFirestoreAlerts(user.uid);
      print("[CaregiverHome] FCM listener demarre");
    }
  }

  Future<void> _listenAlerts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final suiveurDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      String? patientUid = suiveurDoc.data()?['linkedPatient'];

      if (patientUid == null) {
        final p = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'patient')
            .limit(1).get();
        if (p.docs.isNotEmpty) patientUid = p.docs.first.id;
      }
      if (patientUid == null) return;

      FirebaseFirestore.instance
          .collection('users').doc(patientUid)
          .collection('alerts')
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snap) {
        if (mounted) setState(() => _pendingAlerts = snap.docs.length);
      });
    } catch (_) {}
  }

  final List<Widget> _tabs = const [
    CaregiverDashboardTab(),
    CaregiverMapTab(),
    CaregiverAlertsTab(),
    CaregiverProfileTab(),
  ];

  @override
  void dispose() {
    FCMService.stopListeningFirestoreAlerts();
    BackgroundService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),

      floatingActionButton: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6EC6FF), Color(0xFF2EC7F0)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A90E2).withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CaregiverChatbotScreen(),
              ),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(
            Icons.psychology,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20, offset: const Offset(0, -3))],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(children: [
              _navItem(0, Icons.dashboard_rounded, 'Tableau de bord'),
              _navItem(1, Icons.map_rounded, 'Carte'),
              _navItemBadge(2, Icons.notifications_rounded, 'Alertes'),
              _navItem(3, Icons.person_rounded, 'Profil'),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int idx, IconData icon, String label) {
    final sel = _currentIndex == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              gradient: sel ? const LinearGradient(
                colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
              ) : null,
              borderRadius: BorderRadius.circular(16)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                color: sel ? Colors.white : Colors.black38, size: 26),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    color: sel ? Colors.white : Colors.black38)),
          ]),
        ),
      ),
    );
  }

  Widget _navItemBadge(int idx, IconData icon, String label) {
    final sel = _currentIndex == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              gradient: sel ? const LinearGradient(
                colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
              ) : null,
              borderRadius: BorderRadius.circular(16)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(children: [
              Icon(icon,
                  color: sel ? Colors.white : Colors.black38, size: 26),
              if (_pendingAlerts > 0)
                Positioned(right: 0, top: 0,
                    child: Container(
                        width: 16, height: 16,
                        decoration: const BoxDecoration(
                            color: Color(0xFFFF5F6D), shape: BoxShape.circle),
                        child: Center(child: Text('$_pendingAlerts',
                            style: const TextStyle(color: Colors.white, fontSize: 9,
                                fontWeight: FontWeight.bold))))),
            ]),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    color: sel ? Colors.white : Colors.black38)),
          ]),
        ),
      ),
    );
  }
}