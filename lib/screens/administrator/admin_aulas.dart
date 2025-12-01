import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAulasScreen extends StatelessWidget {
  const AdminAulasScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('aulas').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Error al cargar aulas"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) return const Center(child: Text("No hay aulas registradas"));

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final String nombreAula = data['aula'] ?? 'Sin nombre';

            // Procesamiento de coordenadas
            String coordsStr = "No configuradas";
            final dynamic coords = data['coordenadas'];
            if (coords is GeoPoint) {
              coordsStr = "${coords.latitude.toStringAsFixed(5)}, ${coords.longitude.toStringAsFixed(5)}";
            } else if (coords is List && coords.length >= 2) {
              coordsStr = "${coords[0]}, ${coords[1]}";
            }

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.meeting_room, color: Colors.deepOrange),
                ),
                title: Text(nombreAula, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(coordsStr, style: const TextStyle(fontSize: 12)),
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                onTap: () {
                  // Lógica para editar coordenadas (ej: abrir mapa para seleccionar)
                },
              ),
            );
          },
        );
      },
    );
  }
}