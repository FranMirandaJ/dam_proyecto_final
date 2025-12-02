import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'package:proyecto_final/services/auth.dart';
import 'package:proyecto_final/screens/LoginRegister.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({Key? key}) : super(key: key);

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- LÓGICA DE REFRESH INTELIGENTE ---
  void _scheduleNextRefresh(List<QueryDocumentSnapshot> docs) {
    _timer?.cancel();

    final now = DateTime.now();
    DateTime? nextRefreshTime;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final String horaInicioStr = data['hora'] ?? '00:00';
      final String? horaFinRaw = data['horaFin'];

      final start = _parseTimeToday(horaInicioStr, now);

      DateTime end;
      if (horaFinRaw != null) {
        end = _parseTimeToday(horaFinRaw, now);
      } else {
        end = start.add(const Duration(hours: 1));
      }

      if (start.isAfter(now)) {
        if (nextRefreshTime == null || start.isBefore(nextRefreshTime)) {
          nextRefreshTime = start;
        }
      }

      if (end.isAfter(now)) {
        if (nextRefreshTime == null || end.isBefore(nextRefreshTime)) {
          nextRefreshTime = end;
        }
      }
    }

    if (nextRefreshTime != null) {
      final durationUntilRefresh =
          nextRefreshTime.difference(now) + const Duration(minutes: 1);

      _timer = Timer(durationUntilRefresh, () {
        if (mounted) {
          setState(() {});
          _scheduleNextRefresh(docs);
        }
      });
    }
  }

  DateTime _parseTimeToday(String timeStr, DateTime now) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0].trim());
      final minute = int.parse(parts[1].trim());
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      return DateTime(now.year, now.month, now.day, 0, 0);
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

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final Color primaryBlue = const Color(0xFF2563EB);
    final Color backgroundWhite = const Color(0xFFF5F6FA);
    final Color textDark = const Color(0xFF1F222E);

    return Scaffold(
      backgroundColor: primaryBlue,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('clase')
              .where(
                'alumnos',
                arrayContains: FirebaseFirestore.instance.doc(
                  'usuario/${user.uid}',
                ),
              )
              .snapshots(),

          builder: (context, snapshotClases) {
            if (snapshotClases.hasError)
              return const Center(child: Text("Error cargando clases"));
            if (!snapshotClases.hasData)
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );

            final clasesDocsRaw = snapshotClases.data!.docs;

            final List<QueryDocumentSnapshot> sortedDocs = List.from(
              clasesDocsRaw,
            );
            sortedDocs.sort((a, b) {
              final dataA = a.data() as Map<String, dynamic>;
              final dataB = b.data() as Map<String, dynamic>;
              final double tA = _timeStringToDouble(dataA['hora'] ?? '00:00');
              final double tB = _timeStringToDouble(dataB['hora'] ?? '00:00');
              return tA.compareTo(tB);
            });

            int totalClasesEsperadas = 0;
            for (var doc in sortedDocs) {
              final data = doc.data() as Map<String, dynamic>;
              int dictadas = data['totalClasesDictadas'] ?? 0;
              totalClasesEsperadas += dictadas;
            }

            if (_timer == null || !_timer!.isActive) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scheduleNextRefresh(sortedDocs);
              });
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('asistencia')
                  .where(
                    'alumnoId',
                    isEqualTo: FirebaseFirestore.instance.doc(
                      'usuario/${user.uid}',
                    ),
                  )
                  .snapshots(),

              builder: (context, snapshotAsistencias) {
                List<QueryDocumentSnapshot> misAsistenciasDocs = [];
                if (snapshotAsistencias.hasData) {
                  misAsistenciasDocs = snapshotAsistencias.data!.docs;
                }

                int cantidadAsistencias = misAsistenciasDocs.length;

                int clasesEnCursoSinAsistencia = 0;
                final now = DateTime.now();
                final currentDouble = now.hour + now.minute / 60.0;
                final startOfDay = DateTime(now.year, now.month, now.day);
                final endOfDay = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  23,
                  59,
                  59,
                );

                for (var doc in sortedDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final classRef = doc.reference;

                  bool yaChecoHoy = misAsistenciasDocs.any((asist) {
                    final aData = asist.data() as Map<String, dynamic>;
                    final cRef = aData['claseId'];
                    final Timestamp? t = aData['fecha'];
                    if (cRef == classRef && t != null) {
                      final d = t.toDate();
                      return d.isAfter(startOfDay) && d.isBefore(endOfDay);
                    }
                    return false;
                  });

                  if (!yaChecoHoy) {
                    final String horaInicioStr = data['hora'] ?? '00:00';
                    final String? horaFinRaw = data['horaFin'];

                    final double startH = _timeStringToDouble(horaInicioStr);
                    double endH = 0.0;
                    if (horaFinRaw != null) {
                      endH = _timeStringToDouble(horaFinRaw);
                    } else {
                      endH = startH + 1.0;
                    }

                    if (startH > 0 &&
                        currentDouble >= startH &&
                        currentDouble <= endH) {
                      clasesEnCursoSinAsistencia++;
                    }
                  }
                }

                int faltasCalculadas =
                    totalClasesEsperadas - cantidadAsistencias;
                int faltasReales =
                    faltasCalculadas - clasesEnCursoSinAsistencia;

                if (faltasReales < 0) faltasReales = 0;

                double porcentaje = 100.0;
                if (totalClasesEsperadas > 0) {
                  int baseCalculo =
                      totalClasesEsperadas - clasesEnCursoSinAsistencia;
                  if (baseCalculo > 0) {
                    porcentaje = (cantidadAsistencias / baseCalculo) * 100;
                  } else {
                    porcentaje = 100.0;
                  }
                }
                if (porcentaje > 100) porcentaje = 100;
                if (porcentaje < 0) porcentaje = 0;

                String porcentajeStr = porcentaje.toStringAsFixed(0);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Bienvenido de nuevo",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      user.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        user.name.isNotEmpty
                                            ? user.name
                                                  .substring(0, 2)
                                                  .toUpperCase()
                                            : "US",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.1),
                                      ),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.logout_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      tooltip: "Cerrar sesión",
                                      onPressed: () {
                                        Auth().signOut(context);
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const LoginRegister(),
                                          ),
                                          (Route<dynamic> route) => false,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatItem("$porcentajeStr%", "Asistencia"),
                              _buildStatItem(
                                "$totalClasesEsperadas",
                                "Clases Totales",
                              ),
                              _buildStatItem("$faltasReales", "Faltas"),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: backgroundWhite,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30),
                          ),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                30,
                                24,
                                20,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Mis Materias",
                                    style: TextStyle(
                                      color: textDark,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            ),

                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: _handleRefresh,
                                color: primaryBlue,
                                child: sortedDocs.isEmpty
                                    ? ListView(
                                        children: const [
                                          SizedBox(height: 100),
                                          Center(
                                            child: Text(
                                              "No tienes materias inscritas.",
                                              style: TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                        ),
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        itemCount: sortedDocs.length,
                                        itemBuilder: (context, index) {
                                          final data =
                                              sortedDocs[index].data()
                                                  as Map<String, dynamic>;
                                          final classDocRef =
                                              sortedDocs[index].reference;

                                          final String materia =
                                              data['nombre'] ?? 'Sin nombre';

                                          final dynamic aulaField =
                                              data['aula'];
                                          final dynamic profesorField =
                                              data['profesor'];

                                          final String horaInicioStr =
                                              data['hora'] ?? '00:00';
                                          final String? horaFinRaw =
                                              data['horaFin'];

                                          final colors = [
                                            const Color(0xFF00C853),
                                            const Color(0xFF2563EB),
                                            const Color(0xFFFFA000),
                                            const Color(0xFFE91E63),
                                          ];
                                          final color =
                                              colors[index % colors.length];

                                          // FutureBuilder para Aula y Profesor
                                          Future<DocumentSnapshot?> futureAula =
                                              (aulaField is DocumentReference)
                                              ? aulaField.get()
                                              : Future.value(null);

                                          Future<DocumentSnapshot?>
                                          futureProfesor =
                                              (profesorField
                                                  is DocumentReference)
                                              ? profesorField.get()
                                              : Future.value(null);

                                          return FutureBuilder<
                                            List<DocumentSnapshot?>
                                          >(
                                            future: Future.wait([
                                              futureAula,
                                              futureProfesor,
                                            ]),
                                            builder: (context, snapshotFutures) {
                                              String nombreAula = "Sin asignar";
                                              if (aulaField is String) {
                                                nombreAula = aulaField;
                                              } else if (snapshotFutures
                                                      .hasData &&
                                                  snapshotFutures.data![0] !=
                                                      null &&
                                                  snapshotFutures
                                                      .data![0]!
                                                      .exists) {
                                                final aulaData =
                                                    snapshotFutures.data![0]!
                                                            .data()
                                                        as Map<String, dynamic>;
                                                nombreAula =
                                                    aulaData['aula'] ??
                                                    "Aula ??";
                                              }

                                              String nombreProfesor =
                                                  "Sin profesor";
                                              if (snapshotFutures.hasData &&
                                                  snapshotFutures.data![1] !=
                                                      null &&
                                                  snapshotFutures
                                                      .data![1]!
                                                      .exists) {
                                                final profeData =
                                                    snapshotFutures.data![1]!
                                                            .data()
                                                        as Map<String, dynamic>;
                                                nombreProfesor =
                                                    profeData['nombre'] ??
                                                    "Sin nombre";
                                              }

                                              final now = DateTime.now();
                                              final startOfDay = DateTime(
                                                now.year,
                                                now.month,
                                                now.day,
                                              );
                                              final endOfDay = DateTime(
                                                now.year,
                                                now.month,
                                                now.day,
                                                23,
                                                59,
                                                59,
                                              );

                                              bool tieneAsistenciaHoy =
                                                  misAsistenciasDocs.any((
                                                    asistDoc,
                                                  ) {
                                                    final asistData =
                                                        asistDoc.data()
                                                            as Map<
                                                              String,
                                                              dynamic
                                                            >;
                                                    final docRefClase =
                                                        asistData['claseId'];
                                                    final Timestamp? fechaTs =
                                                        asistData['fecha'];

                                                    if (docRefClase ==
                                                            classDocRef &&
                                                        fechaTs != null) {
                                                      final fecha = fechaTs
                                                          .toDate();
                                                      return fecha.isAfter(
                                                            startOfDay,
                                                          ) &&
                                                          fecha.isBefore(
                                                            endOfDay,
                                                          );
                                                    }
                                                    return false;
                                                  });

                                              int estadoActual = 2;
                                              bool enCurso = false;

                                              if (tieneAsistenciaHoy) {
                                                estadoActual = 1;
                                              } else {
                                                final currentTime =
                                                    TimeOfDay.now();
                                                final double currentDouble =
                                                    currentTime.hour +
                                                    currentTime.minute / 60.0;
                                                final double startDouble =
                                                    _timeStringToDouble(
                                                      horaInicioStr,
                                                    );

                                                double endDouble = 0.0;
                                                if (horaFinRaw != null) {
                                                  endDouble =
                                                      _timeStringToDouble(
                                                        horaFinRaw,
                                                      );
                                                } else if (startDouble > 0) {
                                                  endDouble = startDouble + 1.0;
                                                }

                                                if (startDouble > 0) {
                                                  if (currentDouble >
                                                      endDouble) {
                                                    estadoActual = 0; // Falta
                                                  } else if (currentDouble >=
                                                          startDouble &&
                                                      currentDouble <=
                                                          endDouble) {
                                                    estadoActual = 2;
                                                    enCurso = true; // En curso
                                                  }
                                                }
                                              }

                                              return _buildClassCard(
                                                time: horaInicioStr,
                                                endTime: "",
                                                subject: materia,
                                                room: nombreAula,
                                                teacher: nombreProfesor,
                                                status: estadoActual,
                                                isInProgress: enCurso,
                                                accentColor: color,
                                              );
                                            },
                                          );
                                        },
                                      ),
                              ),
                            ),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }

  // --- WIDGET ACTUALIZADO PARA MANEJAR NOMBRES LARGOS ---
  Widget _buildClassCard({
    required String time,
    required String endTime,
    required String subject,
    required String room,
    required String teacher,
    required int status,
    bool isInProgress = false,
    required Color accentColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                child: Row(
                  children: [
                    time != "00:00"
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                time,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF1F222E),
                                ),
                              ),
                            ],
                          )
                        : const Icon(
                            Icons.access_time,
                            size: 20,
                            color: Colors.grey,
                          ),
                    const SizedBox(width: 20),
                    // --- AQUÍ ESTÁ LA MAGIA PARA NOMBRES LARGOS ---
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF1F222E),
                            ),
                            maxLines: 1, // Limita a una línea
                            overflow:
                                TextOverflow.ellipsis, // Pone ... si no cabe
                          ),
                          const SizedBox(height: 4), // Espaciado
                          Text(
                            teacher,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1, // Limita nombre profesor
                            overflow:
                                TextOverflow.ellipsis, // ... si es muy largo
                          ),
                          const SizedBox(height: 4),
                          Text(
                            room,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8), // Espacio extra antes del icono
                    if (status == 1) ...[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF00C853),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Color(0xFF00C853),
                          size: 18,
                        ),
                      ),
                    ] else if (status == 0) ...[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.red, width: 2),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.red,
                          size: 18,
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isInProgress
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFE8F0FE),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isInProgress ? "En curso" : "Pendiente",
                          style: TextStyle(
                            color: isInProgress
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFF2563EB),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
