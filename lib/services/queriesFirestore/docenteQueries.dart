import 'package:cloud_firestore/cloud_firestore.dart';

class DocenteQueries {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Obtiene todas las clases del docente y adjunta las fechas de su periodo.
  static Future<List<Map<String, dynamic>>> obtenerClasesConPeriodos(
      String docenteUid,
      ) async {
    try {
      DocumentReference docRef = _db.collection('usuario').doc(docenteUid);

      // 1. Traer Clases
      final querySnapshot = await _db
          .collection('clase')
          .where('profesor', isEqualTo: docRef)
          .get();

      if (querySnapshot.docs.isEmpty) return [];

      // 2. Procesar en paralelo para buscar los Periodos
      List<Future<Map<String, dynamic>>> futuros = querySnapshot.docs.map((
          doc,
          ) async {
        final data = doc.data();

        // Fechas por defecto (seguridad)
        DateTime inicioPeriodo = DateTime.now().subtract(Duration(days: 365));
        DateTime finPeriodo = DateTime.now().add(Duration(days: 365));

        // 3. Buscar documento del Periodo
        if (data['periodo'] != null && data['periodo'] is DocumentReference) {
          final DocumentReference refPeriodo = data['periodo'];
          final snapPeriodo = await refPeriodo.get();

          if (snapPeriodo.exists) {
            final pData = snapPeriodo.data() as Map<String, dynamic>;
            if (pData['inicio'] != null)
              inicioPeriodo = (pData['inicio'] as Timestamp).toDate();
            if (pData['fin'] != null)
              finPeriodo = (pData['fin'] as Timestamp).toDate();
          }
        }

        return {
          'id': doc.reference.path,
          'nombre': data['nombre'] ?? 'Materia sin nombre',
          // Importante: Asegurar que sea List<int>
          'diasClase': List<int>.from(data['diasClase'] ?? []),
          'periodoInicio': inicioPeriodo,
          'periodoFin': finPeriodo,
        };
      }).toList();

      return await Future.wait(futuros);
    } catch (e) {
      print("Error en obtenerClasesConPeriodos: $e");
      return [];
    }
  }

  /// Obtiene la lista COMPLETA de alumnos (asistentes y faltistas)
  static Future<List<Map<String, dynamic>>> obtenerAsistenciaPorFecha(
      String claseIdPath,
      DateTime fecha,
      ) async {
    try {
      // 1. Definir rango del día exacto para buscar asistencias
      final start = DateTime(fecha.year, fecha.month, fecha.day);
      final end = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59);

      final DocumentReference claseRef = _db.doc(claseIdPath);

      // 2. Ejecutar DOS consultas en paralelo:
      //    A. Obtener la lista completa de inscritos (desde la colección 'clase')
      //    B. Obtener los registros de asistencia de hoy
      final results = await Future.wait([
        claseRef.get(), // Index 0: Datos de la clase
        _db
            .collection('asistencia')
            .where('claseId', isEqualTo: claseRef)
            .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
            .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(end))
            .get(), // Index 1: Asistencias registradas
      ]);

      // --- PROCESAR LISTA OFICIAL DE INSCRITOS ---
      final claseDoc = results[0] as DocumentSnapshot;
      if (!claseDoc.exists) return [];
      final dataClase = claseDoc.data() as Map<String, dynamic>;
      // Obtenemos el array de referencias a usuarios
      final List<dynamic> refsAlumnos = dataClase['alumnos'] ?? [];

      // --- PROCESAR ASISTENCIAS REGISTRADAS ---
      final asistenciaQuery = results[1] as QuerySnapshot;
      final Set<String> idsAsistieron = {}; // Usamos un Set para búsqueda rápida
      final Map<String, DateTime> horasLlegada = {};

      for (var doc in asistenciaQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['alumnoId'] is DocumentReference) {
          final String uid = (data['alumnoId'] as DocumentReference).id;
          idsAsistieron.add(uid);
          if (data['fecha'] != null) {
            horasLlegada[uid] = (data['fecha'] as Timestamp).toDate();
          }
        }
      }

      // 3. Cruzar la información: Recorremos TODOS los alumnos inscritos
      List<Future<Map<String, dynamic>>> futurosAlumnos = refsAlumnos.map((ref) async {
        if (ref is! DocumentReference) return <String, dynamic>{};

        final String uidAlumno = ref.id;
        final bool asistio = idsAsistieron.contains(uidAlumno);

        // Traer nombre del alumno desde la colección 'usuario'
        String nombre = "Cargando...";
        String matricula = uidAlumno;

        final alumnoSnap = await ref.get();
        if (alumnoSnap.exists) {
          final aData = alumnoSnap.data() as Map<String, dynamic>;
          nombre = aData['nombre'] ?? "Sin nombre";

          // Lógica de matrícula: campo explícito o ID recortado
          if (aData['matricula'] != null) {
            matricula = aData['matricula'];
          } else {
            matricula = uidAlumno.length > 5 ? uidAlumno.substring(0, 5).toUpperCase() : uidAlumno;
          }
        }

        return {
          'id': uidAlumno,
          'nombre': nombre,
          'matricula': matricula,
          'asistio': asistio, // TRUE si está en asistencia, FALSE si no
          'horaRegistro': asistio ? horasLlegada[uidAlumno] : null,
        };
      }).toList();

      // Esperar a que se completen todas las mini-consultas de nombres
      final todos = await Future.wait(futurosAlumnos);

      // Filtrar vacíos (por si hubo refs inválidas) y ordenar alfabéticamente
      final listaFinal = todos.where((element) => element.isNotEmpty).toList();
      listaFinal.sort((a, b) => a['nombre'].toString().compareTo(b['nombre'].toString()));

      return listaFinal;

    } catch (e) {
      print("Error obteniendo lista completa: $e");
      return [];
    }
  }
}