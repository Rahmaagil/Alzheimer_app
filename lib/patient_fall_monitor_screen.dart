import 'package:flutter/material.dart';
import 'fall_detection_background_service.dart';

/// Écran de surveillance des chutes.

class PatientFallMonitorScreen extends StatefulWidget {
  const PatientFallMonitorScreen({Key? key}) : super(key: key);

  @override
  State<PatientFallMonitorScreen> createState() => _PatientFallMonitorScreenState();
}

class _PatientFallMonitorScreenState extends State<PatientFallMonitorScreen>
    with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _isMonitoring => FallDetectionBackgroundService.isRunning;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        body: Container(
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
                // AppBar personnalisée
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3142)),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Détection de Chute',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3142),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icône de statut animée
                        _StatusIcon(isActive: _isMonitoring),

                        const SizedBox(height: 32),

                        Text(
                          _isMonitoring
                              ? 'Surveillance Active'
                              : 'Service Inactif',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2D3142),
                          ),
                        ),

                        const SizedBox(height: 12),

                        if (_isMonitoring)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, color: Color(0xFF66BB6A), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Vous êtes protégé(e)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF66BB6A),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Service non démarré',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 48),

                        // Carte d'information
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 40),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: Color(0xFF4A90E2)),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Comment ça fonctionne ?',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2D3142),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              Text(
                                '• Surveillance active même hors de cet écran\n'
                                    '• En cas de chute : 30 secondes pour répondre\n'
                                    '• Pas de réponse → alerte automatique au proche\n'
                                    '• Vous pouvez naviguer librement dans l\'app',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF2D3142),
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Badge "En arrière-plan"
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A90E2).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.layers, color: Color(0xFF4A90E2), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Actif en arrière-plan',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF4A90E2),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Widget icône animée selon l'état du service
// ─────────────────────────────────────────────
class _StatusIcon extends StatefulWidget {
  final bool isActive;
  const _StatusIcon({required this.isActive});

  @override
  State<_StatusIcon> createState() => _StatusIconState();
}

class _StatusIconState extends State<_StatusIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: widget.isActive ? _scaleAnim : const AlwaysStoppedAnimation(1.0),
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: widget.isActive
                ? [const Color(0xFF81C784), const Color(0xFF43A047)]
                : [const Color(0xFF9E9E9E), const Color(0xFF616161)],
          ),
          boxShadow: [
            BoxShadow(
              color: (widget.isActive
                  ? const Color(0xFF66BB6A)
                  : Colors.grey)
                  .withOpacity(0.4),
              blurRadius: 24,
              spreadRadius: 4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          widget.isActive ? Icons.sensors : Icons.sensors_off,
          size: 66,
          color: Colors.white,
        ),
      ),
    );
  }
}