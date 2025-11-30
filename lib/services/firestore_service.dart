import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  static final FirebaseFirestore _instance = FirebaseFirestore.instance;

  // Getter para la instancia única
  static FirebaseFirestore get instance => _instance;

  // Colecciones principales (singleton pattern)
  static CollectionReference get usuarios => _instance.collection('usuario');
  static CollectionReference get aulas => _instance.collection('aulas');
  static CollectionReference get clases => _instance.collection('clase');
  static CollectionReference get asistencias => _instance.collection('asistencia');

  // Métodos comunes útiles para todos
  static String extractIdFromReference(String reference) {
    if (reference.contains('/')) {
      return reference.split('/').last;
    }
    return reference;
  }
}