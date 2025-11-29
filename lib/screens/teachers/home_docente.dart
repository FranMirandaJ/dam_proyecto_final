import 'package:flutter/material.dart';
import 'package:proyecto_final/screens/teachers/dashboard_docente.dart';
import 'package:proyecto_final/screens/teachers/generar_qr.dart';
import 'package:proyecto_final/screens/teachers/notificaciones_docente.dart';

// PLACEHOLDERS
class AttendancePlaceholder extends StatelessWidget {
  const AttendancePlaceholder({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => const Center(child: Text("Asistencia"));
}

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({Key? key}) : super(key: key);

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  int _currentIndex = 0;
  final Color primaryColor = const Color(0xFF2563EB);

  // LISTA DE PANTALLAS
  // Importante: El índice 2 es un "hueco" para el botón central, por eso ponemos un Container vacío.
  late final List<Widget> _screens = [
    TeacherDashboardScreen(),      // Índice 0
    TeacherGenerateQRScreen(),              // Índice 1
    AttendancePlaceholder(),  // Índice 2
    TeacherNotificationScreen()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,

      // Lógica para mostrar la pantalla correcta.
      body: _screens[_currentIndex],

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
                icon: Icon(Icons.qr_code_2),
                label: 'QR',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.group),
                label: 'Asistencia',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications_active),
                label: 'Notificar',
              ),
            ],
          ),
        ),
      ),
    );
  }
}