import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Auth {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream para escuchar cambios de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Obtener el usuario actual
  User? get currentUser => _auth.currentUser;

  // Iniciar sesión con email y contraseña y obtener datos del usuario
  Future<Map<String, dynamic>> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    // Paso 1: Autenticar al usuario
    UserCredential userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Paso 2: Obtener el UID del usuario
    final String uid = userCredential.user!.uid;

    // Paso 3: Buscar el documento del usuario en Firestore
    final DocumentSnapshot doc =
    await _firestore.collection('usuario').doc(uid).get();

    // Paso 4: Comprobar si el documento existe y devolver sus datos
    if (doc.exists) {
      final userData = doc.data() as Map<String, dynamic>;
      userData['uid'] = uid;
      return userData;
    } else {
      // Este caso es poco probable si el registro siempre crea un documento,
      // pero es una buena práctica manejarlo.
      throw Exception("No se encontraron datos de usuario en la base de datos.");
    }
  }

  // Crear usuario con email y contraseña
  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
  }) async {
    if (!email.endsWith('@ittepic.edu.mx')) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'El correo debe ser una dirección institucional.',
      );
    }

    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Si el usuario se crea con éxito, guardar sus datos en Firestore
    if (userCredential.user != null) {
      await _firestore.collection('usuario').doc(userCredential.user!.uid).set({
        'email': email,
        'nombre': fullName,
        'rol': 'alumno', // Asignar rol de alumno por defecto
      });
    }
  }

  // Obtener el rol del usuario desde Firestore
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc =
      await _firestore.collection('usuario').doc(uid).get();
      if (doc.exists) {
        // Corregido de 'role' a 'rol' para coincidir con la base de datos
        return doc.get('rol');
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }
}