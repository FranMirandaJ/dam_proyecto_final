import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Asegúrate de tener intl en pubspec.yaml

class AdminPeriodosScreen extends StatelessWidget {
  const AdminPeriodosScreen({Key? key}) : super(key: key);

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "--";
    if (timestamp is Timestamp) {
      return DateFormat('dd/MM/yyyy').format(timestamp.toDate());
    }
    return timestamp.toString();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('periodos').orderBy('inicio', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) return const Center(child: Text("No hay periodos registrados"));

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final String nombre = data['periodo'] ?? 'Periodo sin nombre';
            final String inicio = _formatTimestamp(data['inicio']);
            final String fin = _formatTimestamp(data['fin']);

            return Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.date_range_rounded, color: Colors.purple, size: 30),
                title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Del $inicio al $fin"),
                onTap: () {
                  // Editar fechas del periodo
                },
              ),
            );
          },
        );
      },
    );
  }
}