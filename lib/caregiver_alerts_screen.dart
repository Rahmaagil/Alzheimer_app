import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';

class CaregiverAlertsTab extends StatefulWidget {
  const CaregiverAlertsTab({super.key});

  @override
  State<CaregiverAlertsTab> createState() => _CaregiverAlertsTabState();
}

class _CaregiverAlertsTabState extends State<CaregiverAlertsTab> {
  String _filterType = 'all';
  String? _patientUid;
  StreamSubscription? _alertsSubscription;
  bool _showStats = false;

  @override
  void initState() {
    super.initState();
    _initPatientUid();
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    _alertsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initPatientUid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String? patientUid = doc.data()?['linkedPatient'];

      if (patientUid == null) {
        final p = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'patient')
            .limit(1)
            .get();
        if (p.docs.isNotEmpty) patientUid = p.docs.first.id;
      }

      if (mounted) {
        setState(() {
          _patientUid = patientUid;
        });
      }

      // Marquer les alertes comme vues
      if (patientUid != null) {
        Future.delayed(const Duration(seconds: 2), () {
          _markAllAlertsAsSeen();
        });
      }
    } catch (e) {
      debugPrint('Error init patient UID: $e');
    }
  }

  void _setupRealtimeListener() {
    _alertsSubscription?.cancel();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Ecouter les nouvelles alertes dans notifications
    _alertsSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('caregiverId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>?;
          if (data != null) {
            _showNotification(data);
          }
        }
      }
    });
  }

  void _showNotification(Map<String, dynamic> alertData) {
    final type = alertData['type'] ?? '';
    final isSOS = type.toLowerCase() == 'sos';
    final isFall = type.toLowerCase() == 'fall' || type.toLowerCase().contains('chute');

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isSOS || isFall
                      ? [const Color(0xFFFF5F6D), const Color(0xFFFFC371)]
                      : [const Color(0xFF6EC6FF), const Color(0xFF4A90E2)],
                ),
              ),
              child: Icon(
                isSOS ? Icons.warning_rounded :
                isFall ? Icons.personal_injury :
                Icons.notification_important,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isSOS ? 'ALERTE SOS !' :
                    isFall ? 'CHUTE DETECTEE !' :
                    'Nouvelle alerte',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    alertData['message'] ?? type,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E5AAC),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<void> _markAllAlertsAsSeen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final pendingQuery = FirebaseFirestore.instance
          .collection('notifications')
          .where('caregiverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending');

      final snapshot = await pendingQuery.get();

      if (snapshot.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'status': 'seen',
          'seenAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error marking alerts as seen: $e');
    }
  }

  Future<void> _markAlertAsResolved(String alertId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(alertId)
          .update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Alerte marquée comme traitée'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error resolving alert: $e');
    }
  }

  Future<void> _deleteAlert(String alertId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(alertId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('Alerte supprimée'),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting alert: $e');
    }
  }

  Future<void> _openLocation(double? lat, double? lon) async {
    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Position non disponible'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error opening location: $e');
    }
  }

  String _formatDateTime(Timestamp? ts) {
    if (ts == null) return '--';
    final d = ts.toDate();
    final now = DateTime.now();
    final t = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    if (d.day == now.day && d.month == now.month && d.year == now.year) {
      return 'Aujourd\'hui à $t';
    }
    if (d.day == now.day - 1 && d.month == now.month && d.year == now.year) {
      return 'Hier à $t';
    }
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} à $t';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: Column(
            children: [
              // Header personnalisé
              _buildHeader(),

              // Toggle Alertes/Statistiques
              _buildToggleButtons(),

              const SizedBox(height: 16),

              // Contenu principal
              Expanded(
                child: _showStats ? _buildStatsView() : _buildAlertsView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Badge nombre alertes
          if (user != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('caregiverId', isEqualTo: user.uid)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.data?.docs.length ?? 0;

                return Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.notifications, color: Colors.white, size: 28),
                      if (count > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5F6D),
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Text(
                              count > 9 ? '9+' : '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(width: 16),

          // Titre
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alertes',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E5AAC),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Surveillance en temps réel',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          // Bouton refresh
          GestureDetector(
            onTap: () {
              setState(() {});
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.refresh_rounded,
                color: Color(0xFF4A90E2),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showStats = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: !_showStats
                      ? const LinearGradient(
                    colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                  )
                      : null,
                  color: _showStats ? Colors.white : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (!_showStats)
                      BoxShadow(
                        color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.list_alt_rounded,
                      color: !_showStats ? Colors.white : const Color(0xFF4A90E2),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Alertes',
                      style: TextStyle(
                        color: !_showStats ? Colors.white : const Color(0xFF4A90E2),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showStats = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: _showStats
                      ? const LinearGradient(
                    colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                  )
                      : null,
                  color: !_showStats ? Colors.white : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (_showStats)
                      BoxShadow(
                        color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bar_chart_rounded,
                      color: _showStats ? Colors.white : const Color(0xFF4A90E2),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Statistiques',
                      style: TextStyle(
                        color: _showStats ? Colors.white : const Color(0xFF4A90E2),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsView() {
    final user = FirebaseAuth.instance.currentUser;

    return Column(
      children: [
        // Filtres
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _buildFilterChip('Toutes', 'all', Icons.apps_rounded),
              const SizedBox(width: 8),
              _buildFilterChip('SOS', 'sos', Icons.warning_rounded),
              const SizedBox(width: 8),
              _buildFilterChip('Zone', 'geofence', Icons.location_off),
              const SizedBox(width: 8),
              _buildFilterChip('Chute', 'fall', Icons.personal_injury),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Liste alertes
        Expanded(
          child: user == null
              ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
            ),
          )
              : StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('caregiverId', isEqualTo: user.uid)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFFF5F6D), Color(0xFFFFC371)],
                          ),
                        ),
                        child: const Icon(Icons.error_outline, color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Erreur de chargement',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              var filtered = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final type = (data['type'] ?? '').toString().toLowerCase();

                if (_filterType == 'all') return true;

                switch (_filterType) {
                  case 'sos':
                    return type == 'sos';
                  case 'geofence':
                    return type.contains('perdu') ||
                        type.contains('geofence') ||
                        type.contains('zone');
                  case 'fall':
                    return type.contains('chute') || type.contains('fall');
                  default:
                    return true;
                }
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                        ),
                        child: const Icon(
                          Icons.notifications_off_outlined,
                          size: 50,
                          color: Color(0xFF4A90E2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Aucune alerte',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E5AAC),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tout va bien pour le moment',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                color: const Color(0xFF4A90E2),
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final doc = filtered[i];
                    final data = doc.data() as Map<String, dynamic>;

                    return _buildAlertCard(
                      alertId: doc.id,
                      type: data['type'] ?? '',
                      message: data['message'] ?? '',
                      timestamp: data['timestamp'],
                      status: data['status'] ?? 'pending',
                      latitude: data['latitude'],
                      longitude: data['longitude'],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _filterType == value;

    return GestureDetector(
      onTap: () => setState(() => _filterType = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
            colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
          )
              : null,
          color: !isSelected ? Colors.white : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF4A90E2),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF4A90E2),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard({
    required String alertId,
    required String type,
    required String message,
    required Timestamp? timestamp,
    required String status,
    required double? latitude,
    required double? longitude,
  }) {
    final hasPos = latitude != null && longitude != null;
    final isSOS = type.toLowerCase() == 'sos';
    final isGeofence = type.toLowerCase().contains('perdu') ||
        type.toLowerCase().contains('geofence') ||
        type.toLowerCase().contains('zone');
    final isFall = type.toLowerCase().contains('chute') ||
        type.toLowerCase().contains('fall');
    final isPending = status == 'pending';

    final List<Color> gradientColors;
    final IconData icon;
    final String label;

    if (isSOS) {
      gradientColors = [const Color(0xFFFF5F6D), const Color(0xFFFFC371)];
      icon = Icons.warning_rounded;
      label = 'Alerte SOS';
    } else if (isGeofence) {
      gradientColors = [const Color(0xFFFFB74D), const Color(0xFFFFA726)];
      icon = Icons.location_off;
      label = 'Sortie de zone';
    } else if (isFall) {
      gradientColors = [const Color(0xFFE91E63), const Color(0xFFEC407A)];
      icon = Icons.personal_injury;
      label = 'Chute détectée';
    } else {
      gradientColors = [const Color(0xFF6EC6FF), const Color(0xFF4A90E2)];
      icon = Icons.notification_important;
      label = type;
    }

    return Dismissible(
      key: Key(alertId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Supprimer l\'alerte ?'),
            content: const Text('Cette action est irréversible.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF5F6D), Color(0xFFFFC371)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Supprimer',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => _deleteAlert(alertId),
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF5F6D), Color(0xFFFFC371)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 36),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(isPending ? 0.15 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Barre de couleur en haut
              Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Icône avec gradient
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: gradientColors),
                            boxShadow: [
                              BoxShadow(
                                color: gradientColors[0].withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 28),
                        ),

                        const SizedBox(width: 16),

                        // Texte
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2E5AAC),
                                      ),
                                    ),
                                  ),
                                  if (isPending)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: gradientColors),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'NOUVEAU',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (message.isNotEmpty)
                                Text(
                                  message,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDateTime(timestamp),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Boutons d'action
                    Row(
                      children: [
                        if (hasPos)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _openLocation(latitude, longitude),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.map, color: Colors.white, size: 20),
                                    SizedBox(width: 6),
                                    Text(
                                      'Localisation',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        if (hasPos) const SizedBox(width: 10),

                        if (status != 'resolved')
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _markAlertAsResolved(alertId),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF43A047).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                                    SizedBox(width: 6),
                                    Text(
                                      'Traité',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsView() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('caregiverId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
            ),
          );
        }

        final alerts = snapshot.data!.docs;

        // Calculer stats
        final now = DateTime.now();
        final last7Days = now.subtract(const Duration(days: 7));
        final last30Days = now.subtract(const Duration(days: 30));

        final alertsLast7Days = alerts.where((doc) {
          final ts = (doc.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (ts == null) return false;
          return ts.toDate().isAfter(last7Days);
        }).toList();

        final alertsLast30Days = alerts.where((doc) {
          final ts = (doc.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (ts == null) return false;
          return ts.toDate().isAfter(last30Days);
        }).toList();

        // Compter par type
        final sosCount = alerts.where((doc) {
          final type = ((doc.data() as Map<String, dynamic>)['type'] ?? '').toString().toLowerCase();
          return type == 'sos';
        }).length;

        final geofenceCount = alerts.where((doc) {
          final type = ((doc.data() as Map<String, dynamic>)['type'] ?? '').toString().toLowerCase();
          return type.contains('perdu') || type.contains('geofence') || type.contains('zone');
        }).length;

        final fallCount = alerts.where((doc) {
          final type = ((doc.data() as Map<String, dynamic>)['type'] ?? '').toString().toLowerCase();
          return type.contains('chute') || type.contains('fall');
        }).length;

        // Données pour le graphique par jour (7 derniers jours)
        final chartData = <String, int>{};
        for (int i = 6; i >= 0; i--) {
          final date = now.subtract(Duration(days: i));
          final key = '${date.day}/${date.month}';
          chartData[key] = 0;
        }

        for (final doc in alertsLast7Days) {
          final ts = (doc.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (ts != null) {
            final date = ts.toDate();
            final key = '${date.day}/${date.month}';
            chartData[key] = (chartData[key] ?? 0) + 1;
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cartes de stats
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Cette semaine',
                      '${alertsLast7Days.length}',
                      Icons.calendar_today,
                      [const Color(0xFF6EC6FF), const Color(0xFF4A90E2)],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Ce mois',
                      '${alertsLast30Days.length}',
                      Icons.calendar_month,
                      [const Color(0xFF66BB6A), const Color(0xFF43A047)],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'SOS',
                      '$sosCount',
                      Icons.warning_rounded,
                      [const Color(0xFFFF5F6D), const Color(0xFFFFC371)],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Chutes',
                      '$fallCount',
                      Icons.personal_injury,
                      [const Color(0xFFE91E63), const Color(0xFFEC407A)],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Graphique
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alertes des 7 derniers jours',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E5AAC),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: (chartData.values.isEmpty ? 0 : chartData.values.reduce((a, b) => a > b ? a : b)).toDouble() + 2,
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final keys = chartData.keys.toList();
                                  if (value.toInt() >= 0 && value.toInt() < keys.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        keys[value.toInt()],
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(show: false),
                          barGroups: chartData.entries.map((entry) {
                            final index = chartData.keys.toList().indexOf(entry.key);
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: entry.value.toDouble(),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                  width: 20,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    topRight: Radius.circular(6),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Répartition par type
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Répartition par type',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E5AAC),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTypeRow('SOS', sosCount, alerts.length,
                        [const Color(0xFFFF5F6D), const Color(0xFFFFC371)]),
                    const SizedBox(height: 12),
                    _buildTypeRow('Sortie de zone', geofenceCount, alerts.length,
                        [const Color(0xFFFFB74D), const Color(0xFFFFA726)]),
                    const SizedBox(height: 12),
                    _buildTypeRow('Chutes', fallCount, alerts.length,
                        [const Color(0xFFE91E63), const Color(0xFFEC407A)]),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, List<Color> colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors[0].withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeRow(String label, int count, int total, List<Color> colors) {
    final percentage = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E5AAC),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '($percentage%)',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}