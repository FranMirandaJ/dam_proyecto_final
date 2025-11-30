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

  /// Obtiene la asistencia de una clase en una fecha específica
  static Future<List<Map<String, dynamic>>> obtenerAsistenciaPorFecha(
    String claseIdPath,
    DateTime fecha,
  ) async {
    try {
      // Definir rango del día completo (00:00 a 23:59)
      final start = DateTime(fecha.year, fecha.month, fecha.day);
      final end = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59);

      final DocumentReference claseRef = _db.doc(claseIdPath);

      final querySnapshot = await _db
          .collection('asistencia')
          .where('claseId', isEqualTo: claseRef)
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();

        // Manejo seguro del ID de matrícula
        String matricula = '---';
        if (data['alumnoId'] != null && data['alumnoId'] is DocumentReference) {
          matricula = (data['alumnoId'] as DocumentReference).id;
          if (matricula.length > 5)
            matricula = matricula.substring(0, 5).toUpperCase();
        }

        return {
          'id': doc.id,
          'nombre': data['nombreAlumno'] ?? 'Sin Nombre Registrado',
          'matricula': matricula,
          'asistio': true,
        };
      }).toList();
    } catch (e) {
      print("Error obteniendo asistencia: $e");
      return [];
    }
  }
}
