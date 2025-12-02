import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentNotificationScreen extends StatefulWidget {
  const StudentNotificationScreen({Key? key}) : super(key: key);

  @override
  State<StudentNotificationScreen> createState() =>
      _StudentNotificationScreenState();
}

class _StudentNotificationScreenState extends State<StudentNotificationScreen>
    with AutomaticKeepAliveClientMixin {
  User? get currentUser => FirebaseAuth.instance.currentUser;

  Stream<QuerySnapshot>? _notificacionesStream;
  Map<String, String> nombresMaterias = {};
  List<String> _leidas = [];
  late Future<void> _cargaInicialFuture;

  @override
  void initState() {
    super.initState();
    _cargaInicialFuture = _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    // 1. Esperamos un poco para asegurar que Auth esté listo
    if (currentUser == null)
      await Future.delayed(const Duration(milliseconds: 500));

    await _cargarNotificacionesLeidas();
    await _inicializarStream();
  }

  Future<void> _cargarNotificacionesLeidas() async {
    final user = currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'leidas_${user.uid}';
    final listaGuardada = prefs.getStringList(key);

    if (mounted) {
      setState(() {
        _leidas = listaGuardada != null ? List<String>.from(listaGuardada) : [];
      });
    }
  }

  Future<void> _marcarComoLeida(String idNotificacion) async {
    final user = currentUser;
    if (user == null) return;

    if (!_leidas.contains(idNotificacion)) {
      setState(() => _leidas.add(idNotificacion)); // Actualización inmediata UI

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('leidas_${user.uid}', _leidas);
      } catch (e) {
        print("Error guardando leída: $e");
      }
    }
  }

  Future<void> _inicializarStream() async {
    final user = currentUser;
    if (user == null) {
      print("❌ [DEBUG] No hay usuario logueado en Notificaciones.");
      return;
    }

    print("🔍 [DEBUG] Buscando clases para alumno UID: ${user.uid}");

    try {
      // Creamos la referencia EXACTAMENTE igual que en Firestore
      // Nota: Asegúrate que en tu BD los alumnos sean de tipo Reference /usuario/ID
      DocumentReference refAlumno = FirebaseFirestore.instance.doc(
        'usuario/${user.uid}',
      );

      final clasesDondeEstoy = await FirebaseFirestore.instance
          .collection('clase')
          .where('alumnos', arrayContains: refAlumno)
          .get();

      print("✅ [DEBUG] Clases encontradas: ${clasesDondeEstoy.docs.length}");

      if (clasesDondeEstoy.docs.isEmpty) {
        if (mounted) setState(() => _notificacionesStream = null);
        return;
      }

      Map<String, String> tempNombres = {};
      List<DocumentReference> listaClasesRefs = [];

      for (var doc in clasesDondeEstoy.docs) {
        String nombre = doc['nombre'] ?? 'Materia';
        String grupo = doc['grupo'] ?? '';
        tempNombres[doc.id] = "$nombre $grupo";
        listaClasesRefs.add(doc.reference);
      }

      // Firestore limita 'whereIn' a 10 elementos. Si son más, tomamos las primeras 10
      // (o tendrías que hacer lógica para más de 10, pero para una escuela es raro)
      if (listaClasesRefs.length > 10) {
        print(
          "⚠️ [AVISO] El alumno tiene más de 10 clases, solo se monitorean las primeras 10.",
        );
        listaClasesRefs = listaClasesRefs.take(10).toList();
      }

      if (mounted) {
        setState(() {
          nombresMaterias = tempNombres;
          _notificacionesStream = FirebaseFirestore.instance
              .collection('notificaciones')
              .where('claseId', whereIn: listaClasesRefs)
              .orderBy('fecha', descending: true)
              .snapshots();
        });
      }
    } catch (e) {
      print("❌ [ERROR] Al cargar notificaciones: $e");
    }
  }

  @override
  bool get wantKeepAlive => true; // Mantiene la pantalla viva

  @override
  Widget build(BuildContext context) {
    super.build(context); // Necesario para KeepAlive

    final Color primaryBlue = const Color(0xFF2563EB);
    final Color textDark = const Color(0xFF1F222E);

    return FutureBuilder(
      future: _cargaInicialFuture,
      builder: (context, snapshotCarga) {
        // Pantalla de carga mientras verificamos clases y preferencias
        if (snapshotCarga.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: Text(
              "Notificaciones",
              style: TextStyle(
                color: textDark,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            actions: [
              StreamBuilder<QuerySnapshot>(
                stream: _notificacionesStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  final docs = snapshot.data!.docs;
                  // Contador filtrado: Solo las NO leídas
                  int sinLeer = docs
                      .where((doc) => !_leidas.contains(doc.id))
                      .length;

                  if (sinLeer == 0) return const SizedBox();

                  return Center(
                    child: Container(
                      margin: const EdgeInsets.only(right: 20),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        "$sinLeer",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: _notificacionesStream == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.class_outlined,
                        size: 50,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "No tienes clases asignadas",
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 5),
                      // Botón para reintentar por si fue error de red
                      TextButton(
                        onPressed: () {
                          setState(
                            () => _cargaInicialFuture = _cargarDatosIniciales(),
                          );
                        },
                        child: const Text("Reintentar"),
                      ),
                    ],
                  ),
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: _notificacionesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          "Sin notificaciones",
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    return ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      itemCount: docs.length + 1,
                      itemBuilder: (context, index) {
                        if (index == docs.length)
                          return const SizedBox(height: 100);

                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final String docId = doc.id;

                        // Verificar si está leída
                        bool isUnread = !_leidas.contains(docId);

                        // Formato Fecha
                        String tiempoAtras = "";
                        if (data['fecha'] != null) {
                          Timestamp t = data['fecha'];
                          tiempoAtras = DateFormat(
                            'dd MMM HH:mm',
                          ).format(t.toDate());
                        }

                        // Icono
                        IconData icono = Icons.notifications_none_rounded;
                        Color colorIcono = primaryBlue;
                        String titulo = data['titulo'] ?? 'Aviso';
                        if (titulo.toLowerCase().contains('examen')) {
                          icono = Icons.warning_amber_rounded;
                          colorIcono = const Color(0xFFFFA000);
                        }

                        // Nombre Materia
                        String nombreMateria = "Materia";
                        try {
                          dynamic claseRef = data['claseId'];
                          String idBusqueda = (claseRef is DocumentReference)
                              ? claseRef.id
                              : claseRef.toString();
                          nombreMateria =
                              nombresMaterias[idBusqueda] ?? "General";
                        } catch (_) {}

                        return GestureDetector(
                          onTap: () => _marcarComoLeida(docId),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: isUnread
                                  ? Colors.white
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(
                                    isUnread ? 0.06 : 0.0,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: IntrinsicHeight(
                                child: Row(
                                  children: [
                                    if (isUnread)
                                      Container(width: 5, color: primaryBlue),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    nombreMateria,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ),
                                                if (isUnread)
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      color: primaryBlue,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  icono,
                                                  size: 20,
                                                  color: isUnread
                                                      ? colorIcono
                                                      : Colors.grey,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    titulo,
                                                    style: TextStyle(
                                                      fontWeight: isUnread
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                      fontSize: 16,
                                                      color: textDark,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              data['cuerpo'] ?? '',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Align(
                                              alignment: Alignment.bottomRight,
                                              child: Text(
                                                tiempoAtras,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade400,
                                                ),
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
                          ),
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }
}
