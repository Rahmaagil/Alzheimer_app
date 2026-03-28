import 'package:alzhecare/caregiver_home_screen.dart';
import 'package:alzhecare/patient_home_screen.dart';
import 'package:alzhecare/reset_password_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:alzhecare/sign_up_screen.dart';
import 'geofencing_service.dart';
import 'user_session_manager.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool hidePassword = true;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!userCredential.user!.emailVerified) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Veuillez vérifier votre email avant de vous connecter."),
              backgroundColor: Colors.orange,
            ),
          );
        }
        await FirebaseAuth.instance.signOut();
        setState(() => _isLoading = false);
        return;
      }

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        String role = userDoc['role'] as String? ?? 'patient';

        await UserSessionManager.saveSession(
          userCredential.user!.uid,
          role,
        );

        if (role == 'patient') {
          await GeofencingService.startTracking(intervalMinutes: 15);
          print("[SignIn] Geofencing démarré pour le patient");
        }

        if (mounted) {
          // MODIFICATION PRINCIPALE: Redirection directe sans vérifier setupCompleted
          if (role == 'patient') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const PatientHomeScreen()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const CaregiverHomeScreen()),
            );
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Connexion réussie en tant que $role"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Utilisateur non trouvé dans la base de données."),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = "Erreur de connexion";
      switch (e.code) {
        case 'user-not-found':
          message = "Aucun compte associé à cet email";
          break;
        case 'wrong-password':
          message = "Mot de passe incorrect";
          break;
        case 'invalid-email':
          message = "Email invalide";
          break;
        case 'user-disabled':
          message = "Compte désactivé";
          break;
        case 'invalid-credential':
          message = "Email ou mot de passe incorrect";
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
                        const Text("Se connecter", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 20),
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
                              return "Entrez votre mot de passe";
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            hintText: "Mot de passe",
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(hidePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => hidePassword = !hidePassword),
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
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
                              );
                            },
                            child: const Text(
                              "Mot de passe oublié ?",
                              style: TextStyle(color: Color(0xFF2E5AAC)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : signIn,
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
                                  "Se connecter",
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
                                MaterialPageRoute(builder: (_) => const SignUpScreen()),
                              );
                            },
                            child: const Text(
                              "Pas de compte ? Créer un compte",
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}