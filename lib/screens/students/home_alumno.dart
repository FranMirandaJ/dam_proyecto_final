import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // NUEVO
import 'package:firebase_auth/firebase_auth.dart';       // NUEVO
import 'package:firebase_messaging/firebase_messaging.dart'; // NUEVO
import 'package:proyecto_final/screens/students/dashboard_alumno.dart';
import 'package:proyecto_final/screens/students/notificaciones_alumno.dart';
import 'package:proyecto_final/screens/students/scanear_qr.dart';
import 'package:proyecto_final/screens/students/mapa.dart';

// PLACEHOLDERS
class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({Key? key}) : super(key: key);

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _currentIndex = 0;
  final Color primaryColor = const Color(0xFF2563EB);

  // LISTA DE PANTALLAS
  late final List<Widget> _screens = [
    StudentDashboardScreen(),      // Índice 0
    Mapa(),                        // Índice 1
    StudentNotificationScreen(),   // Índice 2
  ];

  // --- 1. AQUÍ INICIAMOS LA AUTO-SUSCRIPCIÓN ---
  @override
  void initState() {
    super.initState();
    // Al entrar al Home, verificamos silenciosamente las suscripciones
    _verificarSuscripcionesEnSegundoPlano();
  }

  // --- 2. ESTA ES LA FUNCIÓN SILENCIOSA QUE CONECTA AL ALUMNO ---
  void _verificarSuscripcionesEnSegundoPlano() async {
    User? usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return;

    try {
      final fcm = FirebaseMessaging.instance;

      // A. Pedimos permiso (si ya lo tiene, no hace nada; si no, pregunta)
      await fcm.requestPermission(alert: true, badge: true, sound: true);

      // B. Buscamos las clases (Misma lógica que usamos en notificaciones)
      // Creamos la referencia del alumno para buscar en el array
      DocumentReference refAlumno = FirebaseFirestore.instance
          .collection('usuario')
          .doc(usuario.uid);

      final querySnapshot = await FirebaseFirestore.instance
          .collection('clase')
          .where('alumnos', arrayContains: refAlumno)
          .get();

      // C. Nos suscribimos a todas las clases encontradas
      for (var doc in querySnapshot.docs) {
        String claseId = doc.id;
        String tema = "clase_$claseId";

        // Esto es seguro: si ya estás suscrito, Firebase lo ignora.
        await fcm.subscribeToTopic(tema);
        print("✅ (Auto-Suscripción en Home) Conectado al tema: $tema");
      }
    } catch (e) {
      // Error silencioso para no molestar al usuario
      print("⚠️ Nota: Error leve al intentar suscribirse en segundo plano: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Esto ayuda a que el fondo se vea bien detrás del notch

      // Lógica para mostrar la pantalla correcta.
      body: _screens[_currentIndex],

      // --- 3. BOTÓN FLOTANTE (INTACTO) ---
      floatingActionButton: Transform.translate(
        offset: const Offset(0, -10), // Mueve el botón 10 píxeles hacia arriba
        child: SizedBox(
          width: 40,
          height: 40,
          child: FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => QRScannerScreen()),
              );
            },
            backgroundColor: primaryColor,
            elevation: 4,
            child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 22),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // --- 4. BARRA INFERIOR (INTACTA) ---
      bottomNavigationBar: BottomAppBar(
        child: SizedBox(
          height: 60,
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,

            selectedItemColor: primaryColor,
            unselectedItemColor: Colors.grey.shade400,

            selectedFontSize: 12,
            unselectedFontSize: 12,
            iconSize: 24,

            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Inicio',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map_rounded),
                label: 'Mapa',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications_rounded),
                label: 'Notificaciones',
              ),
            ],
          ),
        ),
      ),
    );
  }
}