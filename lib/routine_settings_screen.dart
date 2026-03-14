import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'daily_routine_service.dart';

class RoutineSettingsScreen extends StatefulWidget {
  const RoutineSettingsScreen({super.key});

  @override
  State<RoutineSettingsScreen> createState() => _RoutineSettingsScreenState();
}

class _RoutineSettingsScreenState extends State<RoutineSettingsScreen> {
  bool _isRoutineEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isRoutineEnabled = prefs.getBool('daily_routine_enabled') ?? false;
      _isLoading = false;
    });
  }

  Future<void> _toggleRoutine(bool value) async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();

    if (value) {
      await DailyRoutineService.scheduleDailyRoutine();
      await prefs.setBool('daily_routine_enabled', true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Routine quotidienne activée"),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } else {
      await DailyRoutineService.cancelAllRoutineNotifications();
      await prefs.setBool('daily_routine_enabled', false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Routine quotidienne désactivée"),
            backgroundColor: Color(0xFFFF9800),
          ),
        );
      }
    }

    setState(() {
      _isRoutineEnabled = value;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF2FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2E5AAC)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Routine quotidienne",
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A90E2)))
            : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Toggle principal
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.notifications_active,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Activer la routine',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E5AAC),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '12 notifications par jour',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isRoutineEnabled,
                      onChanged: _toggleRoutine,
                      activeColor: const Color(0xFF10B981),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Liste des notifications
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Horaires des notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E5AAC),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _notificationItem(Icons.wb_sunny, '7h00', 'Réveil positif', Color(0xFFFFB74D)),
                    _notificationItem(Icons.restaurant, '8h00', 'Petit-déjeuner', Color(0xFF4CAF50)),
                    _notificationItem(Icons.favorite, '9h30', 'Encouragement', Color(0xFFFF5F6D)),
                    _notificationItem(Icons.water_drop, '10h30', 'Hydratation', Color(0xFF4A90E2)),
                    _notificationItem(Icons.lunch_dining, '12h30', 'Déjeuner', Color(0xFF4CAF50)),
                    _notificationItem(Icons.directions_walk, '14h00', 'Activité douce', Color(0xFF9C27B0)),
                    _notificationItem(Icons.water_drop, '15h30', 'Hydratation', Color(0xFF4A90E2)),
                    _notificationItem(Icons.emoji_emotions, '16h30', 'Affirmation positive', Color(0xFFFF9800)),
                    _notificationItem(Icons.water_drop, '17h30', 'Hydratation', Color(0xFF4A90E2)),
                    _notificationItem(Icons.dinner_dining, '19h00', 'Dîner', Color(0xFF4CAF50)),
                    _notificationItem(Icons.self_improvement, '20h00', 'Relaxation', Color(0xFFB794F6)),
                    _notificationItem(Icons.bedtime, '21h00', 'Bonne nuit', Color(0xFF5C6BC0)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withOpacity(0.1),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Les notifications se répètent automatiquement chaque jour aux mêmes heures',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                          height: 1.4,
                        ),
                      ),
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

  Widget _notificationItem(IconData icon, String time, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E5AAC),
                  ),
                ),
                Text(
                  label,
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
    );
  }
}