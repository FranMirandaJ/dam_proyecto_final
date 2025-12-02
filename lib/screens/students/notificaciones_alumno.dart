import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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
    if (currentUser == null)
      await Future.delayed(const Duration(milliseconds: 500));

    await _cargarNotificacionesLeidas();
    await _inicializarStream();
  }

  Future<void> _cargarNotificacionesLeidas() async {
    final user = currentUser;
    if (user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'leidas_${user.uid}';
      final listaGuardada = prefs.getStringList(key);

      if (mounted) {
        setState(() {
          _leidas = listaGuardada != null
              ? List<String>.from(listaGuardada)
              : [];
        });
      }
    } catch (e) {
      debugPrint("Error cargando preferencias: $e");
    }
  }

  Future<void> _marcarComoLeida(String idNotificacion) async {
    final user = currentUser;
    if (user == null) return;

    if (!_leidas.contains(idNotificacion)) {
      setState(() => _leidas.add(idNotificacion));

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('leidas_${user.uid}', _leidas);
      } catch (e) {
        debugPrint("Error guardando leída: $e");
      }
    }
  }

  void _activarNotificacionesFCM(List<DocumentReference> misClases) async {
    try {
      final fcm = FirebaseMessaging.instance;
      await fcm.requestPermission(alert: true, badge: true, sound: true);

      for (var ref in misClases) {
        final topic = "clase_${ref.id}";
        await fcm.subscribeToTopic(topic);
      }
    } catch (e) {
      debugPrint("Error suscribiendo a FCM: $e");
    }
  }

  Future<void> _inicializarStream() async {
    final user = currentUser;
    if (user == null) return;

    try {
      DocumentReference refAlumno = FirebaseFirestore.instance.doc(
        'usuario/${user.uid}',
      );

      final clasesDondeEstoy = await FirebaseFirestore.instance
          .collection('clase')
          .where('alumnos', arrayContains: refAlumno)
          .get();

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

      _activarNotificacionesFCM(listaClasesRefs);

      if (listaClasesRefs.length > 10) {
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
      debugPrint("Error inicializando stream: $e");
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final Color primaryBlue = const Color(0xFF2563EB);
    final Color textDark = const Color(0xFF1F222E);

    return FutureBuilder(
      future: _cargaInicialFuture,
      builder: (context, snapshotCarga) {
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

                  // Contador de notificaciones no leídas
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
                        Icons.notifications_off_outlined,
                        size: 50,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "No tienes clases asignadas",
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          // Solución al error de setState + Future
                          setState(() {
                            _cargaInicialFuture = _cargarDatosIniciales();
                          });
                        },
                        child: const Text("Actualizar"),
                      ),
                    ],
                  ),
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: _notificacionesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());

                    final docs = snapshot.data?.docs;
                    if (docs == null || docs.isEmpty) {
                      return Center(
                        child: Text(
                          "Sin notificaciones",
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      );
                    }

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

                        // Verificar estado de lectura
                        bool isUnread = !_leidas.contains(docId);

                        String tiempoAtras = "";
                        if (data['fecha'] != null) {
                          Timestamp t = data['fecha'];
                          tiempoAtras = DateFormat(
                            'dd MMM HH:mm',
                          ).format(t.toDate());
                        }

                        IconData icono = Icons.notifications_none_rounded;
                        Color colorIcono = primaryBlue;
                        String titulo = data['titulo'] ?? 'Aviso';
                        if (titulo.toLowerCase().contains('examen')) {
                          icono = Icons.warning_amber_rounded;
                          colorIcono = const Color(0xFFFFA000);
                        }

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
                            color: Colors.transparent,
                            child: _buildNotificationCard(
                              icon: icono,
                              iconColor: isUnread ? colorIcono : Colors.grey,
                              title: titulo,
                              body: data['cuerpo'] ?? '',
                              time: tiempoAtras,
                              isUnread: isUnread,
                              materia: nombreMateria,
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

  Widget _buildNotificationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
    required String time,
    required bool isUnread,
    required String materia,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isUnread ? Colors.white : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isUnread ? 0.06 : 0.0),
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
                Container(width: 6, color: const Color(0xFF2563EB))
              else
                const SizedBox(width: 6),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              materia,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(icon, size: 20, color: iconColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: isUnread
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 16,
                                color: const Color(0xFF1F222E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        body,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          time,
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
    );
  }
}
