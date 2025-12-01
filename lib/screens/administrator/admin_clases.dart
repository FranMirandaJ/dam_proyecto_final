import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/manage_clase_modal.dart';

class AdminClasesScreen extends StatelessWidget {
  const AdminClasesScreen({Key? key}) : super(key: key);

  // --- ELIMINACIÓN ---
  Future<void> _confirmarEliminacion(
    BuildContext context,
    String claseId,
    String nombreClase,
  ) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Eliminar Clase?"),
        content: Text(
          "Vas a eliminar la materia '$nombreClase'.\n\nNota: Las asistencias registradas quedarán huérfanas en la base de datos.",
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
              await FirebaseFirestore.instance
                  .collection('clase')
                  .doc(claseId)
                  .delete();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Clase eliminada")),
                );
              }
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clase')
          .orderBy('nombre')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty)
          return const Center(child: Text("No hay clases registradas"));

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
            final alumnosCount = (data['alumnos'] as List?)?.length ?? 0;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.book, color: Colors.indigo),
                ),
                title: Text(
                  nombre,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("$grupo • $hora • $alumnosCount Alumnos"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.grey),
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
