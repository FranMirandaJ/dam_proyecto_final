import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/manage_clase_modal.dart';

class AdminClasesScreen extends StatelessWidget {
  const AdminClasesScreen({Key? key}) : super(key: key);

  Future<void> _confirmarEliminacion(
    BuildContext context,
    String claseId,
    String nombreClase,
  ) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar Clase?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Estás a punto de eliminar la materia '$nombreClase'."),
            const SizedBox(height: 10),
            const Text(
              "ADVERTENCIA: Esta acción eliminará permanentemente la clase Y TODO SU HISTORIAL DE ASISTENCIAS.",
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
              Navigator.pop(ctx);
              await _ejecutarEliminacionCascada(context, claseId);
            },
            child: const Text(
              "Eliminar Todo",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --- LÓGICA DE ELIMINACIÓN EN CASCADA ---
  Future<void> _ejecutarEliminacionCascada(
    BuildContext context,
    String claseId,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final db = FirebaseFirestore.instance;
      final claseRef = db.collection('clase').doc(claseId);

      final asistenciasQuery = await db
          .collection('asistencia')
          .where('claseId', isEqualTo: claseRef)
          .get();

      final batch = db.batch();

      for (var doc in asistenciasQuery.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(claseRef);

      await batch.commit();

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Clase y ${asistenciasQuery.docs.length} asistencias eliminadas.",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
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
          .collection('clase')
          .orderBy('nombre')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text("Error al cargar clases"));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.class_outlined, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 10),
                const Text("No hay clases registradas"),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 80),
          // Espacio para el FAB
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final id = docs[index].id;

            final nombre = data['nombre'] ?? 'Sin nombre';
            final grupo = data['grupo'] ?? '--';
            final hora = data['hora'] ?? '--:--';

            // Contamos alumnos (si el array existe)
            final int alumnosCount = (data['alumnos'] is List)
                ? (data['alumnos'] as List).length
                : 0;

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
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.book, color: Colors.indigo),
                ),
                title: Text(
                  nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            grupo,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(hora, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$alumnosCount Alumnos inscritos",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.grey),
                      tooltip: "Editar",
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (c) =>
                              ManageClaseModal(claseId: id, data: data),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: "Eliminar",
                      onPressed: () =>
                          _confirmarEliminacion(context, id, nombre),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
