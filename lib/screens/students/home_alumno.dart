import 'package:flutter/material.dart';
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
  // Importante: El índice 2 es un "hueco" para el botón central, por eso ponemos un Container vacío.
  late final List<Widget> _screens = [
    StudentDashboardScreen(),      // Índice 0
    Mapa(),              // Índice 1
    StudentNotificationScreen(),    // Índice 2
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Esto ayuda a que el fondo se vea bien detrás del notch

      // Lógica para mostrar la pantalla correcta.
      // Si por error cae en el índice 2 (hueco), mostramos el dashboard para no tronar.
      body: _screens[_currentIndex],

      // --- 1. BOTÓN FLOTANTE ---
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

      // --- 2. BARRA INFERIOR ---
      bottomNavigationBar: BottomAppBar(

        // --- AQUÍ ESTÁ EL ARREGLO DEL ERROR ---
        // Envolvemos el BottomNavigationBar en un Container con altura fija.
        // kBottomNavigationBarHeight es la altura estándar (56.0), le damos un poco más (60)
        // para evitar el overflow de los 2 pixeles.
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

            // Forzamos tamaños de fuente pequeños para que no empujen el layout
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