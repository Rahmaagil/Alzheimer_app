import 'package:alzhecare/lost_patient_screen.dart';
import 'package:alzhecare/reminders_screen.dart';
import 'package:alzhecare/profile_screen.dart';
import 'package:alzhecare/find_home_screen.dart';
import 'package:alzhecare/sign_in_screen.dart';
import 'package:alzhecare/routine_settings_screen.dart';
import 'package:alzhecare/patient_fall_monitor_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'smart_recognition_screen.dart';
import 'geofencing_service.dart';
import 'user_session_manager.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {

  String patientName = "Patient";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _startGeofencing();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() => isLoading = false);
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (doc.exists && doc.data() != null) {
      setState(() {
        patientName = doc.data()!['name'] ?? "Patient";
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _startGeofencing() async {
    try {
      await GeofencingService.startTracking(intervalMinutes: 10);
      debugPrint("[PatientHome] Tracking GPS démarré");
    } catch (e) {
      debugPrint("[PatientHome] Erreur démarrage tracking: $e");
    }
  }

  Future<void> _sendSOS() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final linkedCaregiver = userDoc.data()?['linkedCaregiver'];

    if (linkedCaregiver == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Aucun proche associé"),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

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

    await FirebaseFirestore.instance
        .collection('notifications')
        .add({
      'caregiverId': linkedCaregiver,
      'patientId': user.uid,
      'type': 'sos',
      'title': 'SOS',
      'message': 'Le patient a déclenché une alerte SOS',
      'location': location,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Alerte SOS envoyée à votre proche"),
          backgroundColor: Color(0xFFFF5F6D),
        ),
      );
    }
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
      debugPrint("[PatientHome] Erreur logout: $e");
    }
  }

  @override
  Widget build(BuildContext context) {

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEAF2FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Color(0xFF2E5AAC)),
                    onPressed: () {
                      _showMenu(context);
                    },
                  ),
                  const Text(
                    "Accueil",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E5AAC),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_active,
                          color: Color(0xFF2E5AAC),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RoutineSettingsScreen(),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.person, color: Color(0xFF2E5AAC)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF6EC6FF),
                      Color(0xFF4A90E2),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.psychology,
                  size: 50,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Bonjour,",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                patientName,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E5AAC),
                ),
              ),

              const SizedBox(height: 35),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .collection('reminders')
                    .orderBy('date', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, snapshot) {

                  bool hasReminder =
                      snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                  String reminderText = "Aucun rappel pour le moment";

                  if (hasReminder) {
                    reminderText =
                        snapshot.data!.docs.first.get('title') ?? "Rappel";
                  }

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 25),
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: hasReminder
                          ? const LinearGradient(
                        colors: [
                          Color(0xFF7FB3FF),
                          Color(0xFF2EC7F0),
                        ],
                      )
                          : null,
                      color: hasReminder ? null : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        )
                      ],
                    ),
                    child: Text(
                      reminderText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: hasReminder ? Colors.white : Colors.black87,
                      ),
                    ),
                  );
                },
              ),

              // GRILLE 2x2
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1,
                children: [

                  _buildCard(
                    icon: Icons.home,
                    label: "Mon domicile",
                    colors: const [
                      Color(0xFF7FB3FF),
                      Color(0xFF2EC7F0),
                    ],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FindHomeScreen()),
                      );
                    },
                  ),

                  _buildCard(
                    icon: Icons.location_on,
                    label: "Je suis perdu",
                    colors: const [
                      Color(0xFFFFB74D),
                      Color(0xFFFF7043),
                    ],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LostPatientScreen()),
                      );
                    },
                  ),

                  _buildCard(
                    icon: Icons.notifications,
                    label: "Mes rappels",
                    colors: const [
                      Color(0xFF6EC6FF),
                      Color(0xFF4A90E2),
                    ],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RemindersScreen()),
                      );
                    },
                  ),

                  _buildCard(
                    icon: Icons.face,
                    label: "Mes proches",
                    colors: const [
                      Color(0xFF1DBF73),
                      Color(0xFF11998E),
                    ],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SmartRecognitionScreen()),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // DETECTION CHUTE CENTREE
              Center(
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PatientFallMonitorScreen()),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF5F6D),
                            Color(0xFFFFC371),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5F6D).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 50, color: Colors.white),
                          SizedBox(height: 12),
                          Text(
                            "Détection\nChute",
                            textAlign: TextAlign.center,
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

              const SizedBox(height: 40),

              GestureDetector(
                onTap: _sendSOS,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFFF5F6D),
                        Color(0xFFFF2E63),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFFF5F6D),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      "SOS",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_searching, color: Colors.white),
              ),
              title: const Text("Tester la zone de sécurité"),
              subtitle: const Text("Vérifier si je suis dans ma zone"),
              onTap: () async {
                Navigator.pop(ctx);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text("Vérification en cours..."),
                      ],
                    ),
                    duration: Duration(seconds: 2),
                    backgroundColor: Color(0xFF4A90E2),
                  ),
                );

                await Future.delayed(const Duration(seconds: 2));
                await GeofencingService.checkNow();

                if (mounted) {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    final doc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .get();

                    final lastPos = doc.data()?['lastPosition'];
                    final homeLocation = doc.data()?['homeLocation'];

                    if (lastPos != null && homeLocation != null) {
                      final distance = Geolocator.distanceBetween(
                        lastPos['latitude'],
                        lastPos['longitude'],
                        homeLocation['latitude'],
                        homeLocation['longitude'],
                      );

                      final radius = doc.data()?['safeZoneRadius'] ?? 300;
                      final isInside = distance <= radius;

                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: Row(
                            children: [
                              Icon(
                                isInside ? Icons.check_circle : Icons.warning,
                                color: isInside ? Colors.green : Colors.orange,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                isInside ? "Dans la zone" : "Hors zone",
                                style: TextStyle(
                                  color: isInside ? Colors.green : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Distance: ${distance.toInt()}m",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Limite: ${radius}m",
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isInside
                                    ? "Vous êtes dans votre zone de sécurité."
                                    : "Vous êtes en dehors de votre zone de sécurité.",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4A90E2),
                              ),
                              child: const Text(
                                "OK",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Domicile non configuré"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout, color: Colors.red),
              ),
              title: const Text("Se déconnecter"),
              onTap: () {
                Navigator.pop(ctx);
                _logout();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String label,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: colors.last.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
