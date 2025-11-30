import 'package:cloud_firestore/cloud_firestore.dart';

class EstudianteQueries {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Obtiene una lista de las aulas donde un estudiante específico tiene clase.
  ///
  /// Devuelve una lista de mapas, donde cada mapa contiene el nombre,
  /// la latitud y la longitud del aula.
  static Future<List<Map<String, dynamic>>> getAulasDeEstudiante(String estudianteId) async {
    try {
      // 1. Crea una referencia directa al documento del estudiante.
      final DocumentReference estudianteRef = _firestore.collection('usuario').doc(estudianteId);

      // 2. Busca en la colección 'clase' los documentos donde el array 'alumnos'
      //    contenga la referencia del estudiante.
      final QuerySnapshot clasesSnapshot = await _firestore
          .collection('clase')
          .where('alumnos', arrayContains: estudianteRef)
          .get();

      if (clasesSnapshot.docs.isEmpty) {
        // Si el estudiante no está inscrito en ninguna clase, devuelve una lista vacía.
        return [];
      }

      // 3. Extrae las referencias a las aulas, evitando duplicados.
      final Set<DocumentReference> aulaRefs = {};
      for (var doc in clasesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['aula'] is DocumentReference) {
          aulaRefs.add(data['aula']);
        }
      }

      // 4. Obtiene los datos de cada aula única.
      final List<Map<String, dynamic>> aulasConCoordenadas = [];
      for (DocumentReference ref in aulaRefs) {
        final DocumentSnapshot aulaDoc = await ref.get();
        if (aulaDoc.exists) {
          final aulaData = aulaDoc.data() as Map<String, dynamic>;
          final GeoPoint? coordenadas = aulaData['coordenadas'];
          final String? nombreAula = aulaData['aula'];

          if (coordenadas != null && nombreAula != null) {
            aulasConCoordenadas.add({
              'nombre': nombreAula,
              'latitud': coordenadas.latitude,
              'longitud': coordenadas.longitude,
            });
          }
        }
      }

      return aulasConCoordenadas;

    } catch (e) {
      print('Error al obtener las aulas del estudiante: $e');
      // En caso de error, devuelve una lista vacía para no bloquear la UI.
      return [];
    }
  }
}
