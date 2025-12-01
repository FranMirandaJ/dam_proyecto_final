import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_final/providers/user_provider.dart';
import 'package:firebase_core/firebase_core.dart';

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
    final DocumentSnapshot doc = await _firestore
        .collection('usuario')
        .doc(uid)
        .get();

    // Paso 4: Comprobar si el documento existe y devolver sus datos
    if (doc.exists) {
      final userData = doc.data() as Map<String, dynamic>;
      userData['uid'] = uid;
      return userData;
    } else {
      // Este caso es poco probable si el registro siempre crea un documento,
      // pero es una buena práctica manejarlo.
      throw Exception(
        "No se encontraron datos de usuario en la base de datos.",
      );
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
      DocumentSnapshot doc = await _firestore
          .collection('usuario')
          .doc(uid)
          .get();
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
  Future<void> signOut(BuildContext context) async {
    // Limpiamos el UserProvider
    Provider.of<UserProvider>(context, listen: false).clearUser();
    // Cerramos la sesión en Firebase
    await _auth.signOut();
  }

  Future<void> createTeacherAccount({
    required String email,
    required String password,
    required String fullName,
  }) async {
    FirebaseApp? tempApp;
    try {
      // 1. Inicializamos una instancia secundaria de Firebase
      // Esto evita que se cierre la sesión del Administrador actual
      tempApp = await Firebase.initializeApp(
        name: 'TeacherCreationTempApp',
        options: Firebase.app().options,
      );

      // 2. Creamos el usuario en esa instancia secundaria
      UserCredential userCredential = await FirebaseAuth.instanceFor(
        app: tempApp,
      ).createUserWithEmailAndPassword(email: email, password: password);

      // 3. Guardamos los datos en Firestore (Usando la instancia principal _firestore)
      // Nota: 'rol' es 'docente'
      if (userCredential.user != null) {
        await _firestore
            .collection('usuario')
            .doc(userCredential.user!.uid)
            .set({'email': email, 'nombre': fullName, 'rol': 'docente'});
      }

      // 4. Cerramos sesión en la instancia temporal para limpieza (opcional pero recomendado)
      await FirebaseAuth.instanceFor(app: tempApp).signOut();
    } catch (e) {
      // Propagamos el error para manejarlo en el Modal
      rethrow;
    } finally {
      // 5. Eliminamos la instancia temporal para liberar recursos
      if (tempApp != null) {
        await tempApp.delete();
      }
    }
  }
}
