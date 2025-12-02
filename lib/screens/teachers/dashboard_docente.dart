import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'package:proyecto_final/screens/LoginRegister.dart';
import 'package:proyecto_final/services/auth.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({Key? key}) : super(key: key);

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
      final durationUntilRefresh = nextRefreshTime.difference(now) + const Duration(minutes: 1);

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

    final Color primaryGreen = const Color(0xFF00C853);
    final Color backgroundWhite = const Color(0xFFF5F6FA);
    final Color textDark = const Color(0xFF1F222E);

    return Scaffold(
      backgroundColor: primaryGreen,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('clase')
                .where('profesor', isEqualTo: FirebaseFirestore.instance.doc('usuario/${user.uid}'))
                .snapshots(),

            builder: (context, snapshotClases) {
              if (snapshotClases.hasError) return const Center(child: Text("Error cargando clases"));
              if (!snapshotClases.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

              final clasesDocsRaw = snapshotClases.data!.docs;

              final List<QueryDocumentSnapshot> sortedDocs = List.from(clasesDocsRaw);
              sortedDocs.sort((a, b) {
                final dataA = a.data() as Map<String, dynamic>;
                final dataB = b.data() as Map<String, dynamic>;

                final double tA = _timeStringToDouble(dataA['hora'] ?? '00:00');
                final double tB = _timeStringToDouble(dataB['hora'] ?? '00:00');

                return tA.compareTo(tB);
              });

              List<DocumentReference> listaRefsClases = [];
              int totalClasesDictadasAcumuladas = 0;
              int totalAsistenciasPosibles = 0;

              for (var doc in sortedDocs) {
                final data = doc.data() as Map<String, dynamic>;
                listaRefsClases.add(doc.reference);

                int dictadas = data['totalClasesDictadas'] ?? 0;
                List<dynamic> alumnos = data['alumnos'] ?? [];

                totalClasesDictadasAcumuladas += dictadas;
                totalAsistenciasPosibles += (dictadas * alumnos.length);
              }

              if (_timer == null || !_timer!.isActive) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scheduleNextRefresh(sortedDocs);
                });
              }

              if (listaRefsClases.isEmpty) {
                return _buildBody(
                    context: context,
                    user: user,
                    stats: [0, 0, 0],
                    clasesDocs: [],
                    allAsistencias: [],
                    bgWhite: backgroundWhite,
                    textDark: textDark
                );
              }

              return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('asistencia')
                      .where('claseId', whereIn: listaRefsClases.take(30).toList())
                      .snapshots(),

                  builder: (context, snapshotAsistencias) {
                    List<QueryDocumentSnapshot> todasLasAsistencias = [];
                    if (snapshotAsistencias.hasData) {
                      todasLasAsistencias = snapshotAsistencias.data!.docs;
                    }

                    int totalAsistenciasReales = todasLasAsistencias.length;

                    int totalFaltas = 0;
                    if (totalAsistenciasPosibles >= totalAsistenciasReales) {
                      totalFaltas = totalAsistenciasPosibles - totalAsistenciasReales;
                    }

                    double porcentaje = 0.0;
                    if (totalAsistenciasPosibles > 0) {
                      porcentaje = (totalAsistenciasReales / totalAsistenciasPosibles) * 100;
                    } else if (totalAsistenciasPosibles == 0 && sortedDocs.isNotEmpty) {
                      porcentaje = 100.0;
                    }

                    return _buildBody(
                        context: context,
                        user: user,
                        stats: [porcentaje, totalClasesDictadasAcumuladas, totalFaltas],
                        clasesDocs: sortedDocs,
                        allAsistencias: todasLasAsistencias,
                        bgWhite: backgroundWhite,
                        textDark: textDark,
                        primaryGreen: primaryGreen
                    );
                  }
              );
            }
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required dynamic user,
    required List<num> stats,
    required List<QueryDocumentSnapshot> clasesDocs,
    required List<QueryDocumentSnapshot> allAsistencias,
    required Color bgWhite,
    required Color textDark,
    Color primaryGreen = const Color(0xFF00C853),
  }) {
    String porcentajeStr = stats[0].toStringAsFixed(0);
    String clasesStr = stats[1].toString();
    String faltasStr = stats[2].toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- ENCABEZADO ---
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
                          "Buenos días",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
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
                            user.name.isNotEmpty ? user.name.substring(0, 2).toUpperCase() : "PR",
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
                              MaterialPageRoute(builder: (context) => const LoginRegister()),
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

              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem("$porcentajeStr%", "Asistencia Global"),
                    _buildVerticalDivider(),
                    _buildStatItem(clasesStr, "Clases Dictadas"),
                    _buildVerticalDivider(),
                    _buildStatItem(faltasStr, "Faltas Globales"),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // --- LISTA DE CLASES ---
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: bgWhite,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
                  child: Row(
                    children: [
                      Text(
                        "Mis Clases",
                        style: TextStyle(
                          color: textDark,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _handleRefresh,
                    color: primaryGreen,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: clasesDocs.length,
                      itemBuilder: (context, index) {
                        final data = clasesDocs[index].data() as Map<String, dynamic>;
                        final docRef = clasesDocs[index].reference;

                        final String materia = data['nombre'] ?? 'Sin nombre';
                        final String hora = data['hora'] ?? '00:00';
                        final String? horaFinRaw = data['horaFin'];
                        final List<dynamic> alumnos = data['alumnos'] ?? [];
                        final int totalAlumnos = alumnos.length;

                        // --- LÓGICA DE CLASE ACTIVA (POR HORA) ---
                        bool isClassActive = false;
                        final currentTime = TimeOfDay.now();
                        final double currentDouble = currentTime.hour + currentTime.minute / 60.0;
                        final double startDouble = _timeStringToDouble(hora);

                        double endDouble = 0.0;
                        if (horaFinRaw != null) {
                          endDouble = _timeStringToDouble(horaFinRaw);
                        } else if (startDouble > 0) {
                          endDouble = startDouble + 1.0;
                        }

                        if (startDouble > 0 && endDouble > 0) {
                          // Si está dentro del rango: Activa
                          if (currentDouble >= startDouble && currentDouble <= endDouble) {
                            isClassActive = true;
                          }
                        }

                        final dynamic aulaField = data['aula'];

                        return FutureBuilder<DocumentSnapshot>(
                            future: (aulaField is DocumentReference) ? aulaField.get() : null,
                            builder: (context, snapshotAula) {
                              String nombreAula = "Sin asignar";
                              if (aulaField is String) {
                                nombreAula = aulaField;
                              } else if (snapshotAula.hasData && snapshotAula.data != null && snapshotAula.data!.exists) {
                                final aulaData = snapshotAula.data!.data() as Map<String, dynamic>;
                                nombreAula = aulaData['aula'] ?? "Aula ??";
                              }

                              final now = DateTime.now();
                              final startOfDay = DateTime(now.year, now.month, now.day);
                              final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

                              int asistenciasHoy = allAsistencias.where((asistDoc) {
                                final asistData = asistDoc.data() as Map<String, dynamic>;
                                final dynamic claseRef = asistData['claseId'];
                                final Timestamp? fechaTs = asistData['fecha'];

                                if (fechaTs == null) return false;
                                DateTime fecha = fechaTs.toDate();

                                return claseRef == docRef && fecha.isAfter(startOfDay) && fecha.isBefore(endOfDay);
                              }).length;

                              return _buildClassCard(
                                subject: materia,
                                hora: hora,
                                aula: nombreAula,
                                attendanceRatio: "$asistenciasHoy/$totalAlumnos",
                                isActive: isClassActive,
                                primaryColor: primaryGreen,
                              );
                            }
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
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.white.withOpacity(0.3));
  }

  Widget _buildClassCard({
    required String subject,
    required String hora,
    required String aula,
    required String attendanceRatio,
    required bool isActive,
    required Color primaryColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isActive
            ? Border.all(color: primaryColor, width: 2.0)
            : Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: isActive ? primaryColor.withOpacity(0.15) : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive ? primaryColor : const Color(0xFFF0F1F5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.access_time_filled,
              color: isActive ? Colors.white : Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subject,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1F222E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "En curso",
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    ]
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "$hora • $aula",
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                attendanceRatio,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1F222E),
                ),
              ),
              const Text(
                "asistencias",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}