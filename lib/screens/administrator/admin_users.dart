import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({Key? key}) : super(key: key);

  // --- LÓGICA DE CONFIRMACIÓN Y BORRADO ---
  Future<void> _confirmarEliminacion(BuildContext context, String uid, String nombre, String rol) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("¿Eliminar $rol?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Estás a punto de eliminar a '$nombre'."),
            const SizedBox(height: 10),
            const Text(
              "⚠️ ADVERTENCIA: Esta acción es irreversible y borrará todos los datos asociados (Clases, Asistencias, etc.).",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              if (rol == 'alumno') {
                await _eliminarAlumnoCascada(context, uid);
              } else if (rol == 'docente') {
                await _eliminarDocenteCascada(context, uid);
              }
            },
            child: const Text("Eliminar Definitivamente", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- CASO 1: ELIMINAR ALUMNO ---
  Future<void> _eliminarAlumnoCascada(BuildContext context, String uid) async {
    _mostrarLoading(context);
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final alumnoRef = db.collection('usuario').doc(uid);

      // 1. Borrar todas sus asistencias
      final asistencias = await db.collection('asistencia').where('alumnoId', isEqualTo: alumnoRef).get();
      for (var doc in asistencias.docs) {
        batch.delete(doc.reference);
      }

      // 2. Sacarlo de los arrays 'alumnos' en las clases
      // Nota: ArrayRemove no se puede hacer en batch fácilmente si requiere query previa,
      // así que lo haremos transacción por transacción o una por una.
      // Para eficiencia, buscamos clases donde esté inscrito.
      final clasesInscritas = await db.collection('clase').where('alumnos', arrayContains: alumnoRef).get();
      for (var clase in clasesInscritas.docs) {
        batch.update(clase.reference, {
          'alumnos': FieldValue.arrayRemove([alumnoRef])
        });
      }

      // 3. Borrar usuario
      batch.delete(alumnoRef);

      await batch.commit();

      if (context.mounted) {
        Navigator.pop(context); // Cerrar loading
        _mostrarExito(context, "Alumno eliminado correctamente");
      }
    } catch (e) {
      _manejarError(context, e);
    }
  }

  // --- CASO 2: ELIMINAR DOCENTE ---
  Future<void> _eliminarDocenteCascada(BuildContext context, String uid) async {
    _mostrarLoading(context);
    try {
      final db = FirebaseFirestore.instance;
      final docenteRef = db.collection('usuario').doc(uid);

      // 1. Buscar todas las CLASES del docente
      final clases = await db.collection('clase').where('profesor', isEqualTo: docenteRef).get();

      // Para cada clase, hay que borrar sus asistencias primero
      for (var clase in clases.docs) {
        // Esto es pesado, así que lo hacemos en micro-lotes
        final asistenciasClase = await db.collection('asistencia').where('claseId', isEqualTo: clase.reference).get();

        // Borramos asistencias de esa clase
        final batchAsistencias = db.batch();
        for (var asis in asistenciasClase.docs) {
          batchAsistencias.delete(asis.reference);
        }
        await batchAsistencias.commit();

        // Borramos la clase
        await clase.reference.delete();
      }

      // 2. Borrar notificaciones enviadas por él
      final notifs = await db.collection('notificaciones').where('docenteId', isEqualTo: docenteRef).get();
      final batchNotifs = db.batch();
      for (var notif in notifs.docs) {
        batchNotifs.delete(notif.reference);
      }
      await batchNotifs.commit();

      // 3. Borrar usuario
      await docenteRef.delete();

      if (context.mounted) {
        Navigator.pop(context);
        _mostrarExito(context, "Docente y sus clases eliminados");
      }

    } catch (e) {
      _manejarError(context, e);
    }
  }

  void _mostrarLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _mostrarExito(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  void _manejarError(BuildContext context, Object e) {
    if (Navigator.canPop(context)) Navigator.pop(context); // Cerrar loading si sigue abierto
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
  }

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
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 80), // Espacio para el FAB
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final String uid = docs[index].id;
            final String nombre = data['nombre'] ?? 'Sin nombre';
            final String email = data['email'] ?? 'Sin email';
            final String rol = data['rol'] ?? 'alumno';

            // Color del avatar según rol
            Color avatarColor;
            IconData iconData;

            switch (rol) {
              case 'administrador':
                avatarColor = Colors.redAccent;
                iconData = Icons.admin_panel_settings;
                break;
              case 'docente':
                avatarColor = Colors.teal;
                iconData = Icons.school;
                break;
              default: // alumno
                avatarColor = Colors.blueAccent;
                iconData = Icons.person;
            }

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: avatarColor,
                  child: Icon(iconData, color: Colors.white),
                ),
                title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(email),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge del Rol
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300)
                      ),
                      child: Text(
                        rol.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: avatarColor,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // BOTÓN DE BORRAR (Solo si NO es admin)
                    if (rol != 'administrador')
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: "Eliminar usuario",
                        onPressed: () => _confirmarEliminacion(context, uid, nombre, rol),
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