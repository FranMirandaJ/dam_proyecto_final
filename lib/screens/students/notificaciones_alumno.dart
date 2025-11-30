import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class StudentNotificationScreen extends StatefulWidget {
  const StudentNotificationScreen({Key? key}) : super(key: key);

  @override
  State<StudentNotificationScreen> createState() => _StudentNotificationScreenState();
}

class _StudentNotificationScreenState extends State<StudentNotificationScreen> {
  User? get currentUser => FirebaseAuth.instance.currentUser;
  Stream<QuerySnapshot>? _notificacionesStream;

  // NUEVO: Aquí guardaremos los nombres de las materias (Ej: "id123": "Matemáticas")
  Map<String, String> nombresMaterias = {};

  @override
  void initState() {
    super.initState();
    _inicializarStream();
  }

  void _inicializarStream() async {
    if (currentUser == null) return;

    try {
      DocumentReference refAlumno = FirebaseFirestore.instance
          .collection('usuario')
          .doc(currentUser!.uid);

      final clasesDondeEstoy = await FirebaseFirestore.instance
          .collection('clase')
          .where('alumnos', arrayContains: refAlumno)
          .get();

      if (clasesDondeEstoy.docs.isEmpty) {
        setState(() => _notificacionesStream = null);
        return;
      }

      // NUEVO: Llenamos el diccionario de nombres antes de seguir
      Map<String, String> tempNombres = {};
      for (var doc in clasesDondeEstoy.docs) {
        // Asumimos que el campo en la BD se llama 'nombre' (como en tu imagen anterior)
        String nombreMateria = doc['nombre'] ?? 'Clase';
        tempNombres[doc.id] = nombreMateria;
      }

      List<DocumentReference> listaClasesRefs = clasesDondeEstoy.docs
          .map((doc) => doc.reference)
          .toList();

      // No olvides quitar el listener de aquí si ya lo pusiste en main.dart
      _activarNotificacionesFCM(listaClasesRefs);

      setState(() {
        // Guardamos el mapa de nombres en el estado
        nombresMaterias = tempNombres;

        _notificacionesStream = FirebaseFirestore.instance
            .collection('notificaciones')
            .where('claseId', whereIn: listaClasesRefs)
            .orderBy('fecha', descending: true)
            .snapshots();
      });

    } catch (e) {
      print("ERROR: $e");
    }
  }

  // Solo suscripción (sin listen, porque está en main.dart)
  void _activarNotificacionesFCM(List<DocumentReference> misClases) async {
    final fcm = FirebaseMessaging.instance;
    NotificationSettings settings = await fcm.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      for (var ref in misClases) {
        await fcm.subscribeToTopic("clase_${ref.id}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryBlue = const Color(0xFF2563EB);
    final Color textDark = const Color(0xFF1F222E);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Notificaciones",
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
              stream: _notificacionesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
                return Container(
                  margin: const EdgeInsets.only(right: 20),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: primaryBlue, shape: BoxShape.circle),
                  child: Text(
                    "${snapshot.data!.docs.length}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                );
              }
          ),
        ],
      ),
      body: _notificacionesStream == null
          ? Center(child: Text("Cargando...", style: TextStyle(color: Colors.grey)))
          : StreamBuilder<QuerySnapshot>(
        stream: _notificacionesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data?.docs;
          if (docs == null || docs.isEmpty) {
            return Center(child: Text("Sin notificaciones", style: TextStyle(color: Colors.grey.shade500)));
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            itemCount: docs.length + 1,
            itemBuilder: (context, index) {
              if (index == docs.length) return const SizedBox(height: 100);

              final data = docs[index].data() as Map<String, dynamic>;

              // 1. FECHA
              String tiempoAtras = "Reciente";
              bool esReciente = false;
              if (data['fecha'] != null) {
                Timestamp t = data['fecha'];
                DateTime date = t.toDate();
                Duration diff = DateTime.now().difference(date);
                if (diff.inHours < 24) {
                  esReciente = true;
                  tiempoAtras = diff.inMinutes < 60 ? "Hace ${diff.inMinutes} min" : "Hace ${diff.inHours} h";
                } else {
                  tiempoAtras = DateFormat('dd MMM').format(date);
                }
              }

              // 2. ICONO
              IconData icono = Icons.notifications_none_rounded;
              Color colorIcono = primaryBlue;
              String titulo = data['titulo'] ?? 'Aviso';
              if (titulo.toLowerCase().contains('examen')) {
                icono = Icons.warning_amber_rounded;
                colorIcono = const Color(0xFFFFA000);
              } else if (titulo.toLowerCase().contains('tarea')) {
                icono = Icons.assignment_outlined;
                colorIcono = const Color(0xFF757575);
              }

              // NUEVO: 3. OBTENER NOMBRE MATERIA
              String nombreMateria = "Materia";
              try {
                // Obtenemos el ID de la referencia 'claseId'
                dynamic claseRef = data['claseId'];
                String idBusqueda = '';
                if (claseRef is DocumentReference) {
                  idBusqueda = claseRef.id;
                } else {
                  idBusqueda = claseRef.toString();
                }

                // Buscamos en nuestro diccionario
                nombreMateria = nombresMaterias[idBusqueda] ?? "General";
              } catch (e) {
                print(e);
              }

              return _buildNotificationCard(
                icon: icono,
                iconColor: colorIcono,
                title: titulo,
                body: data['cuerpo'] ?? '',
                time: tiempoAtras,
                isUnread: esReciente,
                materia: nombreMateria, // PASAMOS EL NOMBRE AQUÍ
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    required String time,
    required bool isUnread,
    required String materia, // NUEVO PARÁMETRO
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            children: [
              if (isUnread) Container(width: 6, color: const Color(0xFF2563EB)) else const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                        child: Icon(icon, color: iconColor, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // NUEVO: ETIQUETA DE LA MATERIA ARRIBA DEL TÍTULO
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                materia,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(color: const Color(0xFF1F222E), fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                ),
                                if (isUnread)
                                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(body, style: const TextStyle(color: Color(0xFF757575), fontSize: 13, height: 1.4)),
                            const SizedBox(height: 8),
                            Text(time, style: TextStyle(color: const Color(0xFF9E9E9E), fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}