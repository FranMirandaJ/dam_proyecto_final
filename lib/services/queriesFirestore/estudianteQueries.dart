import 'package:cloud_firestore/cloud_firestore.dart';

class EstudianteQueries {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Obtiene la información completa de las clases de un estudiante (nombre, hora, aula y ubicación).
  ///
  /// Devuelve una lista de mapas, donde cada mapa contiene:
  /// - 'nombreClase': El nombre de la materia.
  /// - 'hora': La hora de la clase.
  /// - 'nombreAula': El nombre del aula.
  /// - 'latitud': La latitud del aula.
  /// - 'longitud': La longitud del aula.
  static Future<List<Map<String, dynamic>>> getClasesInfoParaEstudiante(String estudianteId) async {
    try {
      // 1. Crear una referencia directa al documento del estudiante
      final estudianteRef = _firestore.collection('usuario').doc(estudianteId);

      // 2. Buscar en la colección 'clase' donde el array 'alumnos' contenga la referencia del estudiante
      final clasesSnapshot = await _firestore
          .collection('clase')
          .where('alumnos', arrayContains: estudianteRef)
          .get();

      if (clasesSnapshot.docs.isEmpty) {
        return []; // El estudiante no tiene clases asignadas
      }

      final List<Map<String, dynamic>> clasesInfo = [];

      // 3. Procesar cada clase encontrada
      for (var doc in clasesSnapshot.docs) {
        final claseData = doc.data();

        // Validar que los campos necesarios existan
        if (claseData.containsKey('aula') &&
            claseData['aula'] is DocumentReference &&
            claseData.containsKey('nombre') &&
            claseData.containsKey('hora')) {

          final aulaRef = claseData['aula'] as DocumentReference;
          final aulaSnapshot = await aulaRef.get();

          if (aulaSnapshot.exists) {
            final aulaData = aulaSnapshot.data() as Map<String, dynamic>;

            // Validar que el aula tenga coordenadas
            if (aulaData.containsKey('coordenadas') && aulaData['coordenadas'] is GeoPoint) {
              final geoPoint = aulaData['coordenadas'] as GeoPoint;

              clasesInfo.add({
                'nombreClase': claseData['nombre'],
                'hora': claseData['hora'],
                'nombreAula': aulaData['aula'] ?? 'Aula sin nombre',
                'latitud': geoPoint.latitude,
                'longitud': geoPoint.longitude,
              });
            }
          }
        }
      }

      return clasesInfo;
    } catch (e) {
      print('Error en getClasesInfoParaEstudiante: $e');
      return []; // Devuelve una lista vacía en caso de error
    }
  }
}