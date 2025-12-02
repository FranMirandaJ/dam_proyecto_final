import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/manage_aula_modal.dart'; // Asegúrate de que la ruta sea correcta

class AdminAulasScreen extends StatelessWidget {
  const AdminAulasScreen({Key? key}) : super(key: key);

  // --- LÓGICA DE ELIMINACIÓN SEGURA ---
  Future<void> _confirmarEliminacion(
    BuildContext context,
    String aulaId,
    String nombreAula,
  ) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar Aula?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Estás a punto de eliminar el aula '$nombreAula'."),
            const SizedBox(height: 10),
            const Text(
              "⚠️ ADVERTENCIA: Esta acción eliminará permanentemente todas las clases asignadas a este salón.",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx); // Cerrar diálogo
              await _ejecutarEliminacionCascada(context, aulaId);
            },
            child: const Text(
              "Eliminar",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _ejecutarEliminacionCascada(
    BuildContext context,
    String aulaId,
  ) async {
    // Mostramos un indicador de carga global
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final firestore = FirebaseFirestore.instance;
      final aulaRef = firestore.collection('aulas').doc(aulaId);

      // 1. Buscar todas las clases que tengan este aula asignada
      final clasesQuery = await firestore
          .collection('clase')
          .where('aula', isEqualTo: aulaRef)
          .get();

      // 2. Usar un Batch para operaciones atómicas (todo o nada)
      final batch = firestore.batch();

      // Eliminar las clases encontradas
      for (var doc in clasesQuery.docs) {
        batch.delete(doc.reference);
      }

      // Eliminar el aula
      batch.delete(aulaRef);

      // 3. Ejecutar todo
      await batch.commit();

      if (context.mounted) {
        Navigator.pop(context); // Cerrar loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Se eliminó el aula y ${clasesQuery.docs.length} clases asociadas.",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Cerrar loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al eliminar: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('aulas')
          .orderBy('aula')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text("Error al cargar aulas"));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.meeting_room_outlined,
                  size: 60,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 10),
                const Text("No hay aulas registradas"),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(
            top: 10,
            bottom: 80,
            left: 10,
            right: 10,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final String aulaId = docs[index].id;
            final String nombreAula = data['aula'] ?? 'Sin nombre';

            // Procesamiento seguro de coordenadas
            GeoPoint? geoPoint;
            String coordsDisplay = "Sin configurar";

            final dynamic rawCoords = data['coordenadas'];
            if (rawCoords is GeoPoint) {
              geoPoint = rawCoords;
              coordsDisplay =
                  "${rawCoords.latitude.toStringAsFixed(5)}, ${rawCoords.longitude.toStringAsFixed(5)}";
            } else if (rawCoords is List && rawCoords.length >= 2) {
              // Soporte para formato array [lat, lng]
              geoPoint = GeoPoint(rawCoords[0], rawCoords[1]);
              coordsDisplay = "${rawCoords[0]}, ${rawCoords[1]}";
            }

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.room, color: Colors.deepOrange),
                ),
                title: Text(
                  nombreAula,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.gps_fixed, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        coordsDisplay,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () =>
                      _confirmarEliminacion(context, aulaId, nombreAula),
                ),
                onTap: () {
                  // ABRIR MODAL PARA EDITAR
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ManageAulaModal(
                      aulaId: aulaId,
                      currentName: nombreAula,
                      currentCoords: geoPoint,
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
