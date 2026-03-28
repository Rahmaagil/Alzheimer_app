import 'package:alzhecare/caregiver_map_tab.dart';
import 'package:alzhecare/caregiver_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CaregiverDashboardTab extends StatefulWidget {
  const CaregiverDashboardTab({super.key});
  @override
  State<CaregiverDashboardTab> createState() => _CaregiverDashboardTabState();
}

class _CaregiverDashboardTabState extends State<CaregiverDashboardTab> {
  Map<String, dynamic>? _patientData;
  Map<String, dynamic>? _lastPosition;
  List<Map<String, dynamic>> _recentAlerts = [];
  bool _isLoading = true;
  String? _patientUid;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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
        debugPrint('[Dashboard] Aucun patient lié');
        setState(() => _isLoading = false);
        return;
      }

      // Afficher le PREMIER patient de la liste
      final patientUid = linkedPatients.first;
      _patientUid = patientUid;

      debugPrint('[Dashboard] Affichage patient: $patientUid');

      final patDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .get();
      _patientData = patDoc.data();
      _lastPosition = _patientData?['lastPosition'];

      // MODIFIE: Charger alertes depuis collection notifications
      final alertsSnap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('caregiverId', isEqualTo: user.uid)
          .where('patientId', isEqualTo: patientUid)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      final list = alertsSnap.docs.map((d) {
        final data = d.data();
        return {
          'type': data['type'] ?? '',
          'timestamp': data['timestamp'],
          'status': data['status'] ?? 'pending',
        };
      }).toList();

      list.sort((a, b) {
        final ta = a['timestamp'] as Timestamp?;
        final tb = b['timestamp'] as Timestamp?;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

      _recentAlerts = list;
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('[Dashboard] Erreur: $e');
      setState(() => _isLoading = false);
    }
  }

  bool get _isSafe {
    if (_recentAlerts.isEmpty) return true;
    final lastAlert = _recentAlerts.first;
    final type = lastAlert['type'] as String;
    final timestamp = lastAlert['timestamp'] as Timestamp?;

    if (timestamp == null) return true;

    final diff = DateTime.now().difference(timestamp.toDate());
    final isRecent = diff.inMinutes < 30;
    final isDangerous = (type == 'sos' || type == 'lost' || type == 'fall');

    return !(isRecent && isDangerous);
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return 'Inconnue';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'A l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return 'Il y a ${diff.inDays}j';
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '--:--';
    final d = ts.toDate();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        title: const Text(
          "Tableau de bord",
          style: TextStyle(
              color: Color(0xFF2E5AAC),
              fontWeight: FontWeight.bold,
              fontSize: 22),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Color(0xFF2E5AAC)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const CaregiverSettingsScreen()),
              );
            },
            tooltip: 'Parametres',
          ),
        ],
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
            ? const Center(
            child:
            CircularProgressIndicator(color: Color(0xFF4A90E2)))
            : _patientData == null
            ? _noPatientWidget()
            : RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF4A90E2),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // BADGE AVATAR
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
                  child: const Icon(Icons.person,
                      color: Colors.white, size: 50),
                ),

                const SizedBox(height: 16),

                Text(
                  _patientData?['name'] ?? 'Patient',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E5AAC),
                  ),
                ),

                const SizedBox(height: 30),

                // STATUT
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: _isSafe
                        ? const LinearGradient(
                      colors: [
                        Color(0xFF81C784),
                        Color(0xFF66BB6A)
                      ],
                    )
                        : const LinearGradient(
                      colors: [
                        Color(0xFFFF5F6D),
                        Color(0xFFFF2E63)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: _isSafe
                            ? const Color(0xFF66BB6A).withValues(alpha: 0.3)
                            : const Color(0xFFFF5F6D).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _isSafe
                            ? Icons.check_circle_rounded
                            : Icons.warning_rounded,
                        color: Colors.white,
                        size: 60,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isSafe ? 'En Securite' : 'Alerte Active',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _lastPosition != null
                            ? 'Position GPS disponible'
                            : 'Position inconnue',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // DERNIERE POSITION
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
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
                      const Row(
                        children: [
                          Icon(Icons.location_on,
                              color: Color(0xFF4A90E2), size: 24),
                          SizedBox(width: 10),
                          Text(
                            'Derniere position',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E5AAC),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      if (_lastPosition == null)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'Aucune position disponible',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black38,
                              ),
                            ),
                          ),
                        )
                      else ...[
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF6EC6FF),
                                      Color(0xFF4A90E2)
                                    ],
                                  ),
                                  borderRadius:
                                  BorderRadius.circular(14),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.my_location,
                                        color: Colors.white, size: 24),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${(_lastPosition!['latitude'] as num).toStringAsFixed(5)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const Text(
                                      'Latitude',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF7FB3FF),
                                      Color(0xFF2EC7F0)
                                    ],
                                  ),
                                  borderRadius:
                                  BorderRadius.circular(14),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.explore,
                                        color: Colors.white, size: 24),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${(_lastPosition!['longitude'] as num).toStringAsFixed(5)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const Text(
                                      'Longitude',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(Icons.access_time,
                                color: Color(0xFF4A90E2), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _timeAgo(_lastPosition?['updatedAt']),
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                    const CaregiverMapTab()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(30),
                              ),
                              padding: EdgeInsets.zero,
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                            ),
                            child: Ink(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF7FB3FF),
                                    Color(0xFF2EC7F0)
                                  ],
                                ),
                                borderRadius: BorderRadius.all(
                                    Radius.circular(30)),
                              ),
                              child: const Center(
                                child: Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.map_rounded,
                                        color: Colors.white, size: 22),
                                    SizedBox(width: 10),
                                    Text(
                                      'Voir sur la carte',
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
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ALERTES RECENTES
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
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
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.notifications_rounded,
                                  color: Color(0xFFFFB74D), size: 24),
                              SizedBox(width: 10),
                              Text(
                                'Alertes recentes',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E5AAC),
                                ),
                              ),
                            ],
                          ),
                          if (_recentAlerts.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF5F6D),
                                    Color(0xFFFFC371)
                                  ],
                                ),
                                borderRadius:
                                BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_recentAlerts.length}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      if (_recentAlerts.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: const Color(0xFF4CAF50)
                                      .withValues(alpha: 0.6),
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Aucune alerte',
                                  style: TextStyle(
                                    fontSize: 17,
                                    color: Color(0xFF4CAF50),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._recentAlerts.take(3).map((a) {
                          final type = (a['type'] as String).toLowerCase();
                          final isSOS = type == 'sos';
                          final isFall = type == 'fall' || type.contains('chute');
                          final color = isSOS
                              ? const Color(0xFFFF5F6D)
                              : isFall
                              ? const Color(0xFFE91E63)
                              : const Color(0xFFFFB74D);
                          final icon = isSOS
                              ? Icons.warning_rounded
                              : isFall
                              ? Icons.personal_injury
                              : Icons.location_off;
                          final label = isSOS
                              ? 'Alerte SOS'
                              : isFall
                              ? 'Chute detectee'
                              : type.contains('perdu') || type.contains('lost')
                              ? 'Patient perdu'
                              : type.contains('geofence') || type.contains('zone')
                              ? 'Sortie de zone'
                              : type;

                          return Container(
                            margin:
                            const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isSOS
                                    ? [
                                  const Color(0xFFFF5F6D),
                                  const Color(0xFFFFC371)
                                ]
                                    : isFall
                                    ? [
                                  const Color(0xFFE91E63),
                                  const Color(0xFFEC407A)
                                ]
                                    : [
                                  const Color(0xFFFFB74D),
                                  const Color(0xFFFFA726)
                                ],
                              ),
                              borderRadius:
                              BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                  color.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withValues(alpha: 0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(icon,
                                      color: Colors.white, size: 26),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTime(a['timestamp']),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios,
                                    color: Colors.white, size: 18),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _noPatientWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4A90E2).withOpacity(0.1),
            ),
            child: const Icon(
              Icons.person_add_outlined,
              size: 60,
              color: Color(0xFF4A90E2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aucun patient lié',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E5AAC),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Générez un code d\'invitation dans votre profil pour lier un patient',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}