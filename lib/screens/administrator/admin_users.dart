import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('usuario').orderBy('rol').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Error al cargar usuarios"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Center(child: Text("No hay usuarios registrados"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final String nombre = data['nombre'] ?? 'Sin nombre';
            final String email = data['email'] ?? 'Sin email';
            final String rol = data['rol'] ?? 'alumno';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: rol == 'docente' ? Colors.teal : Colors.blueAccent,
                  child: Icon(
                    rol == 'docente' ? Icons.person_4 : Icons.person,
                    color: Colors.white,
                  ),
                ),
                title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(email),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: rol == 'admin' ? Colors.redAccent : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    rol.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: rol == 'admin' ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                onTap: () {
                  // Lógica para editar usuario
                },
              ),
            );
          },
        );
      },
    );
  }
}