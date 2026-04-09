import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

/// Service de liaison entre patients et suiveurs via codes d'invitation
class PatientCaregiverLinkService {


  /// Génère un code d'invitation unique (6 caractères)
  /// Exclut O, I, 0, 1 pour éviter confusion
  static String generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Crée un code d'invitation pour un suiveur
  ///
  /// [caregiverUid] - UID Firebase du suiveur
  /// [expiryHours] - Durée validité code (défaut: 24h)
  ///
  /// Retourne le code généré ou null si erreur
  static Future<String?> createInviteCode({
    required String caregiverUid,
    int expiryHours = 24,
  }) async {
    try {
      final code = generateInviteCode();
      final expiresAt = DateTime.now().add(Duration(hours: expiryHours));

      print("[InviteCode] Création code: $code pour caregiver: $caregiverUid");

      // Vérifier que le code n'existe pas déjà
      final existingCode = await FirebaseFirestore.instance
          .collection('inviteCodes')
          .doc(code)
          .get();

      if (existingCode.exists) {
        print("[InviteCode] Code existe déjà, régénération...");
        return createInviteCode(
          caregiverUid: caregiverUid,
          expiryHours: expiryHours,
        );
      }

      // Créer document code
      await FirebaseFirestore.instance
          .collection('inviteCodes')
          .doc(code)
          .set({
        'caregiverId': caregiverUid,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'usedBy': [],
        'status': 'active',
      });

      // Sauvegarder dans profil suiveur (pour référence)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverUid)
          .update({
        'currentInviteCode': code,
        'inviteCodeExpiry': Timestamp.fromDate(expiresAt),
      });

      print("[InviteCode] Code créé avec succès, expire le: $expiresAt");
      return code;

    } catch (e, stackTrace) {
      print("[InviteCode] ERREUR création: $e");
      print("[InviteCode] StackTrace: $stackTrace");
      return null;
    }
  }



  /// Valide et utilise un code d'invitation (côté patient)
  ///
  /// [patientUid] - UID Firebase du patient
  /// [code] - Code à 6 caractères
  ///
  /// Retourne Map avec:
  /// - success (bool): true si liaison réussie
  /// - message (String): message erreur/succès
  /// - caregiverName (String): nom du suiveur (si succès)
  /// - caregiverId (String): UID du suiveur (si succès)
  static Future<Map<String, dynamic>> linkPatientWithCode({
    required String patientUid,
    required String code,
  }) async {
    try {
      final codeUpper = code.toUpperCase().trim();
      print("[LinkCode] Patient $patientUid utilise code: $codeUpper");

      // Récupérer document code
      final codeDoc = await FirebaseFirestore.instance
          .collection('inviteCodes')
          .doc(codeUpper)
          .get();

      if (!codeDoc.exists) {
        print("[LinkCode] Code invalide: $codeUpper");
        return {
          'success': false,
          'message': 'Code invalide',
        };
      }

      final data = codeDoc.data()!;
      final status = data['status'];
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final caregiverId = data['caregiverId'];

      // Vérification statut
      if (status != 'active') {
        print("[LinkCode] Code non actif: $status");
        return {
          'success': false,
          'message': 'Code déjà utilisé ou expiré',
        };
      }

      // Vérification expiration
      if (DateTime.now().isAfter(expiresAt)) {
        print("[LinkCode] Code expiré");
        // Marquer comme expiré
        await codeDoc.reference.update({'status': 'expired'});
        return {
          'success': false,
          'message': 'Code expiré',
        };
      }

      // Vérifier que patient pas déjà lié à ce suiveur
      final patientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .get();

      final linkedCaregivers = List<String>.from(
          patientDoc.data()?['linkedCaregivers'] ?? []
      );

      if (linkedCaregivers.contains(caregiverId)) {
        print("[LinkCode] Patient déjà lié à ce suiveur");
        return {
          'success': false,
          'message': 'Vous êtes déjà lié à ce proche',
        };
      }

      // Récupérer infos suiveur
      final caregiverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverId)
          .get();

      if (!caregiverDoc.exists) {
        print("[LinkCode] Suiveur introuvable");
        return {
          'success': false,
          'message': 'Suiveur introuvable',
        };
      }

      final caregiverName = caregiverDoc.data()?['name'] ?? 'Suiveur';
      final caregiverEmail = caregiverDoc.data()?['email'] ?? '';

      // CREATION LIAISON BIDIRECTIONNELLE
      print("[LinkCode] Création liaison bidirectionnelle...");

      // 1. Ajouter suiveur à la liste du patient
      await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .set({
        'linkedCaregivers': FieldValue.arrayUnion([caregiverId]),
        'lastLinkedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("[LinkCode] Suiveur ajouté à liste patient");

      // 2. Ajouter patient à la liste du suiveur
      await FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverId)
          .set({
        'linkedPatients': FieldValue.arrayUnion([patientUid]),
        'lastLinkedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("[LinkCode] Patient ajouté à liste suiveur");

      // 3. Marquer code comme utilisé
      await codeDoc.reference.update({
        'usedBy': FieldValue.arrayUnion([patientUid]),
        'lastUsedAt': FieldValue.serverTimestamp(),
      });

      print("[LinkCode] Code marqué comme utilisé");
      print("[LinkCode] Liaison réussie avec $caregiverName ($caregiverEmail)");

      return {
        'success': true,
        'message': 'Liaison réussie',
        'caregiverName': caregiverName,
        'caregiverId': caregiverId,
      };

    } catch (e, stackTrace) {
      print("[LinkCode] ERREUR: $e");
      print("[LinkCode] StackTrace: $stackTrace");
      return {
        'success': false,
        'message': 'Erreur technique: $e',
      };
    }
  }



  /// Supprime un suiveur spécifique de la liste d'un patient
  ///
  /// [patientUid] - UID du patient
  /// [caregiverUid] - UID du suiveur à retirer
  static Future<bool> unlinkSpecificCaregiver({
    required String patientUid,
    required String caregiverUid,
  }) async {
    try {
      print("[Unlink] Suppression liaison patient=$patientUid, caregiver=$caregiverUid");

      // Retirer patient de liste suiveur
      await FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverUid)
          .update({
        'linkedPatients': FieldValue.arrayRemove([patientUid]),
      });

      // Retirer suiveur de liste patient
      await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .update({
        'linkedCaregivers': FieldValue.arrayRemove([caregiverUid]),
      });

      print("[Unlink] Liaison supprimée avec succès");
      return true;

    } catch (e) {
      print("[Unlink]  Erreur: $e");
      return false;
    }
  }

  /// Récupère la liste des suiveurs liés à un patient
  ///
  /// Retourne liste de Map avec: uid, name, email, phone
  static Future<List<Map<String, dynamic>>> getPatientCaregivers(
      String patientUid,
      ) async {
    try {
      final patientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .get();

      if (!patientDoc.exists) return [];

      final caregiverIds = List<String>.from(
          patientDoc.data()?['linkedCaregivers'] ?? []
      );

      if (caregiverIds.isEmpty) {
        print("[GetCaregivers] Aucun suiveur lié");
        return [];
      }

      print("[GetCaregivers] Récupération ${caregiverIds.length} suiveur(s)");

      final caregivers = <Map<String, dynamic>>[];

      for (final caregiverId in caregiverIds) {
        final caregiverDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(caregiverId)
            .get();

        if (caregiverDoc.exists) {
          final data = caregiverDoc.data()!;
          caregivers.add({
            'uid': caregiverId,
            'name': data['name'] ?? 'Inconnu',
            'email': data['email'] ?? '',
            'phone': data['phone'] ?? '',
          });
        }
      }

      print("[GetCaregivers] ${caregivers.length} suiveur(s) récupéré(s)");
      return caregivers;

    } catch (e) {
      print("[GetCaregivers] Erreur: $e");
      return [];
    }
  }

  /// Récupère la liste des patients liés à un suiveur
  ///
  /// Retourne liste de Map avec: uid, name, email
  static Future<List<Map<String, dynamic>>> getCaregiverPatients(
      String caregiverUid,
      ) async {
    try {
      final caregiverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverUid)
          .get();

      if (!caregiverDoc.exists) return [];

      final patientIds = List<String>.from(
          caregiverDoc.data()?['linkedPatients'] ?? []
      );

      if (patientIds.isEmpty) {
        print("[GetPatients] Aucun patient lié");
        return [];
      }

      print("[GetPatients] Récupération ${patientIds.length} patient(s)");

      final patients = <Map<String, dynamic>>[];

      for (final patientId in patientIds) {
        final patientDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(patientId)
            .get();

        if (patientDoc.exists) {
          final data = patientDoc.data()!;
          patients.add({
            'uid': patientId,
            'name': data['name'] ?? 'Inconnu',
            'email': data['email'] ?? '',
            'age': data['age'],
            'diseaseStage': data['diseaseStage'],
          });
        }
      }

      print("[GetPatients] ${patients.length} patient(s) récupéré(s)");
      return patients;

    } catch (e) {
      print("[GetPatients] Erreur: $e");
      return [];
    }
  }


  /// Supprime tous les codes expirés (maintenance)
  /// A appeler périodiquement (ex: Cloud Function)
  static Future<int> cleanupExpiredCodes() async {
    try {
      final now = Timestamp.now();

      final expiredCodes = await FirebaseFirestore.instance
          .collection('inviteCodes')
          .where('expiresAt', isLessThan: now)
          .where('status', isEqualTo: 'active')
          .get();

      int count = 0;
      final batch = FirebaseFirestore.instance.batch();

      for (final doc in expiredCodes.docs) {
        batch.update(doc.reference, {'status': 'expired'});
        count++;
      }

      await batch.commit();

      print("[Cleanup] $count code(s) marqué(s) comme expiré(s)");
      return count;

    } catch (e) {
      print("[Cleanup] Erreur: $e");
      return 0;
    }
  }
}