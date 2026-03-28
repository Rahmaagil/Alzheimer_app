import 'package:alzhecare/sign_in_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'geofencing_service.dart';
import 'user_session_manager.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool hidePassword = true;
  bool hideConfirmPassword = true;
  bool _isLoading = false;
  String _selectedRole = 'patient';

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  Future<void> signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Structure de base
      Map<String, dynamic> userData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Ajouter champs selon rôle
      if (_selectedRole == 'patient') {
        userData['linkedCaregivers'] = [];  // Liste vide de suiveurs
      } else if (_selectedRole == 'suiveur') {
        userData['linkedPatients'] = [];    // Liste vide de patients
        userData['phone'] = _phoneController.text.trim();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(userData);

      await UserSessionManager.saveSession(
        userCredential.user!.uid,
        _selectedRole,
      );

      // Si patient, démarrer le geofencing
      if (_selectedRole == 'patient') {
        await GeofencingService.startTracking(intervalMinutes: 15);
        print("[SignUp] Geofencing démarré pour le patient");
      }

      await userCredential.user!.sendEmailVerification();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Compte créé ! Vérifiez votre email pour continuer."),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SignInScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = "Erreur lors de l'inscription";
      switch (e.code) {
        case 'invalid-email':
          message = "Adresse email invalide";
          break;
        case 'email-already-in-use':
          message = "Cet email est déjà utilisé";
          break;
        case 'weak-password':
          message = "Mot de passe trop faible (minimum 6 caractères)";
          break;
        default:
          message = e.message ?? "Erreur inconnue";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [Color(0xFF6EC6FF), Color(0xFF4A90E2)]),
                      boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 20)],
                    ),
                    child: const Icon(Icons.psychology, color: Colors.white, size: 42),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "AlzheCare",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2E5AAC)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Une assistance intelligente au quotidien",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Créer un compte", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _nameController,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return "Entrez votre nom complet";
                            }
                            if (val.trim().length < 3) {
                              return "Le nom doit contenir au moins 3 caractères";
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: "Nom complet",
                            prefixIcon: const Icon(Icons.person_outline),
                            filled: true,
                            fillColor: const Color(0xFFF3F6FF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Colors.red, width: 1),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return "Entrez votre email";
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                              return "Email invalide";
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: "votre@gmail.com",
                            prefixIcon: const Icon(Icons.email_outlined),
                            filled: true,
                            fillColor: const Color(0xFFF3F6FF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Colors.red, width: 1),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: hidePassword,
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return "Entrez un mot de passe";
                            }
                            if (val.length < 6) {
                              return "Minimum 6 caractères";
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: "Mot de passe",
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(hidePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () {
                                setState(() => hidePassword = !hidePassword);
                              },
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF3F6FF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Colors.red, width: 1),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: hideConfirmPassword,
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return "Confirmez votre mot de passe";
                            }
                            if (val != _passwordController.text) {
                              return "Les mots de passe ne correspondent pas";
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: "Confirmer le mot de passe",
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(hideConfirmPassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () {
                                setState(() => hideConfirmPassword = !hideConfirmPassword);
                              },
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF3F6FF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Colors.red, width: 1),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Sélectionnez votre rôle",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF3F6FF),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'patient', child: Text('Patient')),
                            DropdownMenuItem(value: 'suiveur', child: Text('Suiveur')),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedRole = value!);
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_selectedRole == 'suiveur') ...[
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return "Le téléphone est obligatoire pour un suiveur";
                              }
                              if (val.trim().length < 8) {
                                return "Numéro de téléphone invalide";
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              hintText: "Votre numéro de téléphone",
                              prefixIcon: const Icon(Icons.phone),
                              filled: true,
                              fillColor: const Color(0xFFF3F6FF),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Colors.red, width: 1),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Color(0xFF4A90E2)),
                                SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    "Votre numéro pour vous contacter",
                                    style: TextStyle(fontSize: 12, color: Color(0xFF4A90E2)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : signUp,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              padding: EdgeInsets.zero,
                              backgroundColor: Colors.transparent,
                              disabledBackgroundColor: Colors.grey,
                              elevation: 0,
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: _isLoading
                                    ? null
                                    : const LinearGradient(colors: [Color(0xFF7FB3FF), Color(0xFF2EC7F0)]),
                                color: _isLoading ? Colors.grey : null,
                                borderRadius: const BorderRadius.all(Radius.circular(30)),
                              ),
                              child: Center(
                                child: _isLoading
                                    ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                                    : const Text(
                                  "Créer un compte",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const SignInScreen()),
                              );
                            },
                            child: const Text(
                              "Déjà un compte ? Se connecter",
                              style: TextStyle(color: Color(0xFF2E5AAC)),
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
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}