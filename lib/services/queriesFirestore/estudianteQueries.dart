import 'package:cloud_firestore/cloud_firestore.dart';

class EstudianteQueries {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<List<Map<String, dynamic>>> getClasesInfoParaEstudiante(
      String estudianteId) async {
    try {
      final estudianteRef = _firestore.collection('usuario').doc(estudianteId);

      final clasesSnapshot = await _firestore
          .collection('clase')
          .where('alumnos', arrayContains: estudianteRef)
          .get();

      if (clasesSnapshot.docs.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> clasesInfo = [];

      for (var doc in clasesSnapshot.docs) {
        final claseData = doc.data();

        // Validamos que los campos necesarios existan
        if (claseData.containsKey('aula') &&
            claseData['aula'] is DocumentReference &&
            claseData.containsKey('nombre') &&
            claseData.containsKey('hora') &&
            claseData.containsKey('horaFin')) { // <-- Se añade la validación para horaFin

          final aulaRef = claseData['aula'] as DocumentReference;
          final aulaSnapshot = await aulaRef.get();

          if (aulaSnapshot.exists) {
            final aulaData = aulaSnapshot.data() as Map<String, dynamic>;

            if (aulaData.containsKey('coordenadas') &&
                aulaData['coordenadas'] is GeoPoint) {
              final geoPoint = aulaData['coordenadas'] as GeoPoint;

              clasesInfo.add({
                'nombreClase': claseData['nombre'],
                'hora': claseData['hora'],
                'horaFin': claseData['horaFin'], // <-- Se añade horaFin al mapa
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
      return [];
    }
  }
}
