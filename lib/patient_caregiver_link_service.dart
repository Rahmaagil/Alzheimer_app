import 'package:cloud_firestore/cloud_firestore.dart';

class PatientCaregiverLinkService {

  static Future<bool> linkPatientToCaregiver({
    required String patientUid,
    required String caregiverPhone,
  }) async {
    try {

      print("[Link] Patient UID: $patientUid");
      print("[Link] Numero cherche: $caregiverPhone");

      // Étape 1 : Récupérer TOUS les utilisateurs pour debug
      final allUsers = await FirebaseFirestore.instance
          .collection('users')
          .get();

      print("[Link] Total utilisateurs dans la base: ${allUsers.docs.length}");

      for (var doc in allUsers.docs) {
        final data = doc.data();
        print("[Link] - ${data['name']}: role=${data['role']}, phone=${data['phone']}");
      }

      // Étape 2 : Chercher le suiveur avec ce numéro
      DocumentSnapshot? caregiverDoc;

      for (var doc in allUsers.docs) {
        final data = doc.data();

        if (data['phone'] == caregiverPhone &&
            (data['role'] == 'suiveur' || data['role'] == 'caregiver')) {
          caregiverDoc = doc;
          print("[Link] TROUVE: ${data['name']} (${doc.id})");
          break;
        }
      }

      if (caregiverDoc == null) {
        print("[Link] Aucun suiveur trouve avec phone=$caregiverPhone");
        return false;
      }

      final caregiverUid = caregiverDoc.id;
      final caregiverData = caregiverDoc.data() as Map<String, dynamic>;

      print("[Link] Suiveur trouve: ${caregiverData['name']} (UID: $caregiverUid)");

      // Étape 3 : Créer la liaison bidirectionnelle
      print("[Link] Creation liaison bidirectionnelle...");

      await FirebaseFirestore.instance
          .collection('users')
          .doc(caregiverUid)
          .update({
        'linkedPatient': patientUid,
        'linkedAt': FieldValue.serverTimestamp(),
      });

      print("[Link] linkedPatient ajoute au suiveur");

      await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .update({
        'linkedCaregiver': caregiverUid,
        'linkedAt': FieldValue.serverTimestamp(),
      });

      print("[Link] linkedCaregiver ajoute au patient");


      return true;

    } catch (e, stackTrace) {
      print("[Link] ERREUR: $e");
      print("[Link] StackTrace: $stackTrace");
      return false;
    }
  }

  static Future<void> unlinkPatientAndCaregiver(String patientUid) async {
    try {
      final patientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .get();

      if (!patientDoc.exists) return;

      final caregiverUid = patientDoc.data()?['linkedCaregiver'] as String?;

      if (caregiverUid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(caregiverUid)
            .update({'linkedPatient': FieldValue.delete()});
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(patientUid)
          .update({'linkedCaregiver': FieldValue.delete()});

      print("[Link] Liaison supprimee");
    } catch (e) {
      print("[Link] Erreur suppression liaison: $e");
    }
  }
}
