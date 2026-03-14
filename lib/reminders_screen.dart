import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'reminder_notification_service.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Map<String, dynamic>> _reminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reminders')
          .orderBy('date', descending: false)
          .get();

      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? '',
          'date': data['date'] as Timestamp?,
          'done': data['done'] ?? false,
        };
      }).where((reminder) => !(reminder['done'] as bool)).toList();

      setState(() {
        _reminders = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Erreur: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleDone(String docId, bool currentDone) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reminders')
          .doc(docId)
          .update({'done': !currentDone});

      // Annuler la notification
      await ReminderNotificationService.cancelReminder(docId);

      _loadReminders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  !currentDone ? Icons.check_circle : Icons.refresh,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Text(!currentDone ? "Fait" : "A faire"),
              ],
            ),
            backgroundColor:
            !currentDone ? const Color(0xFF66BB6A) : const Color(0xFF4A90E2),
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint("Erreur: $e");
    }
  }

  Future<void> _deleteReminder(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Supprimer ce rappel ?"),
        content: const Text("Cette action est irreversible."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF5F6D), Color(0xFFFFC371)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                "Supprimer",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reminders')
          .doc(docId)
          .delete();

      // Annuler la notification
      await ReminderNotificationService.cancelReminder(docId);

      _loadReminders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text("Rappel supprime"),
              ],
            ),
            backgroundColor: const Color(0xFF66BB6A),
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint("Erreur: $e");
    }
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '--:--';
    final d = ts.toDate();
    return "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    return "${d.day}/${d.month}/${d.year}";
  }

  void _showAddDialog() {
    final titleController = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF0F7FF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
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
                      labelStyle: const TextStyle(fontSize: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setDialogState(() => selectedDate = date);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF4A90E2), width: 2),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.calendar_today,
                                    color: Color(0xFF4A90E2), size: 28),
                                const SizedBox(height: 8),
                                Text(
                                  "${selectedDate.day}/${selectedDate.month}",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E5AAC),
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
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (time != null) {
                              setDialogState(() => selectedTime = time);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFF4A90E2), width: 2),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.access_time,
                                    color: Color(0xFF4A90E2), size: 28),
                                const SizedBox(height: 8),
                                Text(
                                  selectedTime.format(context),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E5AAC),
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Annuler", style: TextStyle(fontSize: 16)),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextButton(
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Entrez un titre")),
                        );
                        return;
                      }

                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) return;

                      final reminderDateTime = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );

                      try {
                        // Ajouter dans Firestore
                        final docRef = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('reminders')
                            .add({
                          'title': title,
                          'date': Timestamp.fromDate(reminderDateTime),
                          'done': false,
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                        // Programmer la notification
                        await ReminderNotificationService.scheduleReminder(
                          reminderId: docRef.id,
                          title: title,
                          scheduledTime: reminderDateTime,
                        );

                        Navigator.pop(dialogContext);

                        await Future.delayed(const Duration(milliseconds: 300));
                        _loadReminders();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 12),
                                  Text("Rappel ajoute"),
                                ],
                              ),
                              backgroundColor: const Color(0xFF66BB6A),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: Colors.white),
                                  const SizedBox(width: 12),
                                  Text("Erreur: $e"),
                                ],
                              ),
                              backgroundColor: const Color(0xFFFF5F6D),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      }
                    },
                    child: const Text(
                      "Ajouter",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF2FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2E5AAC)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Mes Rappels",
          style: TextStyle(
            color: Color(0xFF2E5AAC),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showAddDialog,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
        ),
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
            ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF4A90E2)))
            : _reminders.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
          onRefresh: _loadReminders,
          color: const Color(0xFF4A90E2),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children:
            _reminders.map((r) => _buildReminderCard(r)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildReminderCard(Map<String, dynamic> reminder) {
    final title = reminder['title'] as String;
    final ts = reminder['date'] as Timestamp?;
    final docId = reminder['id'] as String;
    final isDone = reminder['done'] as bool;
    final timeText = _formatTime(ts);
    final dateText = _formatDate(ts);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDone ? Colors.grey[100] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDone ? 0.04 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _toggleDone(docId, isDone),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: isDone
                      ? LinearGradient(
                    colors: [Colors.grey[400]!, Colors.grey[500]!],
                  )
                      : const LinearGradient(
                    colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isDone
                      ? []
                      : [
                    BoxShadow(
                      color: const Color(0xFFFFB74D).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.notifications_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDone ? Colors.grey[600] : const Color(0xFF2E5AAC),
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationThickness: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: isDone ? Colors.grey[500] : Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          dateText,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDone ? Colors.grey[500] : Colors.grey[700],
                            decoration:
                            isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: isDone ? Colors.grey[500] : Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          timeText,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDone ? Colors.grey[500] : Colors.grey[700],
                            decoration:
                            isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Column(
                children: [
                  Icon(
                    isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isDone
                        ? const Color(0xFF66BB6A)
                        : const Color(0xFF9CA3AF),
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _deleteReminder(docId),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5F6D).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFFF5F6D),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
              Icons.notifications_none_rounded,
              size: 50,
              color: Color(0xFF4A90E2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Aucun rappel",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E5AAC),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Appuyez sur + pour ajouter un rappel",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}