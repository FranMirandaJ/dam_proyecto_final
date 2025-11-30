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

  static Future<List<Map<String, dynamic>>> obtenerAsistenciaPorFecha(
    String claseIdPath,
    DateTime fecha,
  ) async {
    try {
      // 1. Definir rango del día exacto
      final start = DateTime(fecha.year, fecha.month, fecha.day);
      final end = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59);

      // Convertimos el string path (ej: "clase/ABC...") a DocumentReference
      final DocumentReference claseRef = _db.doc(claseIdPath);

      // 2. Traer las fichas de asistencia
      final querySnapshot = await _db
          .collection('asistencia')
          .where('claseId', isEqualTo: claseRef)
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      if (querySnapshot.docs.isEmpty) return [];

      // 3. Procesar cada asistencia para buscar el NOMBRE del alumno
      // Usamos Future.wait para hacer todas las consultas de nombre en paralelo
      List<Future<Map<String, dynamic>>>
      futurosAlumnos = querySnapshot.docs.map((doc) async {
        final data = doc.data();

        String nombreAlumno = "Desconocido";
        String matricula = "---";

        // Verificamos si hay una referencia al alumno
        if (data['alumnoId'] != null && data['alumnoId'] is DocumentReference) {
          DocumentReference alumnoRef = data['alumnoId'];

          // --- CONSULTA EXTRA: Leer datos del usuario ---
          final alumnoSnap = await alumnoRef.get();

          if (alumnoSnap.exists) {
            final alumnoData = alumnoSnap.data() as Map<String, dynamic>;
            nombreAlumno = alumnoData['nombre'] ?? "Sin Nombre";

            // Usamos el ID del documento usuario como matrícula (común en estos sistemas)
            matricula = alumnoRef.id;
            if (matricula.length > 8)
              matricula = matricula.substring(0, 8).toUpperCase();
          }
        }

        return {
          'id': doc.id,
          'nombre': nombreAlumno,
          // Ahora sí tenemos el nombre real
          'matricula': matricula,
          'asistio': true,
          'horaRegistro': (data['fecha'] as Timestamp).toDate(),
          // Dato extra útil
        };
      }).toList();

      return await Future.wait(futurosAlumnos);
    } catch (e) {
      print("Error obteniendo asistencia: $e");
      return [];
    }
  }
}
