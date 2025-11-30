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
  final Color primaryColor = const Color(0xFF00C853); // Verde Docente

  // Mantenemos las pantallas, PERO la del QR será dinámica
  // Usamos un placeholder vacío por mientras en el índice 1,
  // porque la navegación la controlaremos manualmente.
  late final List<Widget> _screens = [
    const TeacherDashboardScreen(),      // Índice 0
    Container(),                         // Índice 1 (QR - Controlado por función)
    AsistenciasPage(),       // Índice 2
    const TeacherNotificationScreen()    // Índice 3
  ];

  // Función para validar si hay clase y navegar
  Future<void> _handleQRNavigation(String uid) async {
    // 1. Mostrar carga rápida
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final now = DateTime.now();
      final double currentDouble = now.hour + now.minute / 60.0;

      // 2. Traer clases del profesor
      final querySnapshot = await FirebaseFirestore.instance
          .collection('clase')
          .where('profesor', isEqualTo: FirebaseFirestore.instance.doc('usuario/$uid'))
          .get();

      // 3. Buscar si alguna coincide con la hora actual
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
          end = start + 1.0; // Fallback 1 hora
        }

        // Validación de rango
        if (start > 0 && end > 0) {
          if (currentDouble >= start && currentDouble <= end) {
            claseActiva = doc;
            datosClase = data;
            break; // Encontramos la clase actual, dejamos de buscar
          }
        }
      }

      // Cerrar loading
      Navigator.pop(context);

      // 4. Navegar o Mostrar Error
      if (claseActiva != null && datosClase != null) {
        // --- EXTRAER DATOS REALES ---
        final String nombreClase = datosClase['nombre'] ?? 'Clase';
        final String claseId = claseActiva.id;

        // Resolver Aula (si es referencia o string)
        String nombreAula = "Sin aula";
        final dynamic aulaField = datosClase['aula'];
        if (aulaField is String) {
          nombreAula = aulaField;
        } else if (aulaField is DocumentReference) {
          final aulaDoc = await aulaField.get();
          if (aulaDoc.exists) {
            nombreAula = aulaDoc['aula'] ?? "Aula"; // Ajusta según tu campo en 'aulas'
          }
        }

        // Contar alumnos
        final List<dynamic> alumnos = datosClase['alumnos'] ?? [];
        final int cantidadAlumnos = alumnos.length;

        // Navegar a la pantalla de Generar QR con datos reales
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TeacherGenerateQRScreen(
              claseId: claseId,
              nombreClase: nombreClase,
              // Tendrás que agregar estos campos al constructor de GenerarQR (ver abajo)
              nombreAula: nombreAula,
              cantidadAlumnos: cantidadAlumnos,
            ),
          ),
        );
      } else {
        // No hay clase en este momento
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("No tienes ninguna clase programada en este horario."),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

    } catch (e) {
      Navigator.pop(context); // Cerrar loading si falla
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
    // Obtenemos el UID del usuario para la consulta
    final userProvider = Provider.of<UserProvider>(context);
    final uid = userProvider.user?.uid;

    return Scaffold(
      extendBody: true,

      // Cuerpo
      body: _screens[_currentIndex],

      // Barra de Navegación
      bottomNavigationBar: BottomAppBar(
        child: SizedBox(
          height: 60,
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              if (index == 1) {
                // SI PULSA EL ÍCONO DE QR (Índice 1)
                // Ejecutamos la validación en lugar de cambiar de pestaña ciegamente
                if (uid != null) {
                  _handleQRNavigation(uid);
                }
              } else {
                // Navegación normal para los otros tabs
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
                icon: Icon(Icons.qr_code_2), // Botón que valida horario
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