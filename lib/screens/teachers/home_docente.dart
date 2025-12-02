import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:proyecto_final/screens/teachers/dashboard_docente.dart';
import 'package:proyecto_final/screens/teachers/generar_qr.dart';
import 'package:proyecto_final/screens/teachers/notificaciones_docente.dart';
import '../../providers/user_provider.dart';
import 'package:proyecto_final/screens/teachers/asistencia.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({Key? key}) : super(key: key);

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  int _currentIndex = 0;
  final Color primaryColor = const Color(0xFF00C853);

  late final List<Widget> _screens = [
    const TeacherDashboardScreen(),
    Container(),
    AsistenciasPage(),
    const TeacherNotificationScreen()
  ];


  Future<void> _handleQRNavigation(String uid) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final now = DateTime.now();
      final double currentDouble = now.hour + now.minute / 60.0;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('clase')
          .where('profesor', isEqualTo: FirebaseFirestore.instance.doc('usuario/$uid'))
          .get();

      QueryDocumentSnapshot? claseActiva;
      Map<String, dynamic>? datosClase;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final String horaInicioStr = data['hora'] ?? '00:00';
        final String? horaFinRaw = data['horaFin'];

        final double start = _timeStringToDouble(horaInicioStr);
        double end = 0.0;

        if (horaFinRaw != null) {
          end = _timeStringToDouble(horaFinRaw);
        } else if (start > 0) {
          end = start + 1.0;
        }

        // Validación de rango
        if (start > 0 && end > 0) {
          if (currentDouble >= start && currentDouble <= end) {
            claseActiva = doc;
            datosClase = data;
            break;
          }
        }
      }

      Navigator.pop(context);

      if (claseActiva != null && datosClase != null) {

        final String nombreClase = datosClase['nombre'] ?? 'Clase';
        final String claseId = claseActiva.id;

        String nombreAula = "Sin aula";
        final dynamic aulaField = datosClase['aula'];
        if (aulaField is String) {
          nombreAula = aulaField;
        } else if (aulaField is DocumentReference) {
          final aulaDoc = await aulaField.get();
          if (aulaDoc.exists) {
            nombreAula = aulaDoc['aula'] ?? "Aula";
          }
        }

        final List<dynamic> alumnos = datosClase['alumnos'] ?? [];
        final int cantidadAlumnos = alumnos.length;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TeacherGenerateQRScreen(
              claseId: claseId,
              nombreClase: nombreClase,
              nombreAula: nombreAula,
              cantidadAlumnos: cantidadAlumnos,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("No tienes ninguna clase programada en este horario."),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

    } catch (e) {
      Navigator.pop(context);
      print("Error buscando clase activa: $e");
    }
  }

  double _timeStringToDouble(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length != 2) return 0.0;
      final hour = int.parse(parts[0].trim());
      final minute = int.parse(parts[1].trim());
      return hour + minute / 60.0;
    } catch (e) {
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final uid = userProvider.user?.uid;

    return Scaffold(
      extendBody: true,

      body: _screens[_currentIndex],

      bottomNavigationBar: BottomAppBar(
        child: SizedBox(
          height: 60,
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              if (index == 1) {
                if (uid != null) {
                  _handleQRNavigation(uid);
                }
              } else {
                setState(() {
                  _currentIndex = index;
                });
              }
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