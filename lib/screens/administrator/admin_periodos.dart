import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'widgets/manage_periodo_modal.dart';

class AdminPeriodosScreen extends StatelessWidget {
  const AdminPeriodosScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // Ordenamos por inicio descendente para ver lo más nuevo arriba
      stream: FirebaseFirestore.instance
          .collection('periodos')
          .orderBy('inicio', descending: true)
          .snapshots(),

      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text("Error al cargar datos"));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 10),
                const Text("No hay periodos registrados"),
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
            final String id = docs[index].id;
            final String nombre = data['periodo'] ?? '---';

            DateTime? inicio, fin;
            if (data['inicio'] != null)
              inicio = (data['inicio'] as Timestamp).toDate();
            if (data['fin'] != null) fin = (data['fin'] as Timestamp).toDate();

            final dateFormat = DateFormat('dd MMM yyyy');

            // --- LÓGICA DE ESTADO (VISUAL) ---
            final now = DateTime.now();

            // Estado por defecto
            String estadoLabel = "DESCONOCIDO";
            Color estadoColor = Colors.grey;
            bool isCurrent = false;

            if (inicio != null && fin != null) {
              // Ajustamos fin al final del día para comparación justa
              final endOfFin = DateTime(
                fin.year,
                fin.month,
                fin.day,
                23,
                59,
                59,
              );

              if (now.isBefore(inicio)) {
                estadoLabel = "PRÓXIMO";
                estadoColor = Colors.blue;
              } else if (now.isAfter(endOfFin)) {
                estadoLabel = "FINALIZADO";
                estadoColor = Colors.grey;
              } else {
                estadoLabel = "ACTUAL";
                estadoColor = Colors.green;
                isCurrent = true;
              }
            }

            return Card(
              elevation: isCurrent ? 4 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                // Borde verde si es el actual para destacarlo
                side: isCurrent
                    ? const BorderSide(color: Color(0xFF3F51B5), width: 2)
                    : BorderSide.none,
              ),
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: estadoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.date_range, color: estadoColor),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        nombre,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isCurrent ? Colors.black : Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Chip de estado
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: estadoColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        estadoLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(
                    "${inicio != null ? dateFormat.format(inicio) : '?'}  —  ${fin != null ? dateFormat.format(fin) : '?'}",
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ),
                // Quitamos el icono de basura (trailing)
                // Solo dejamos el tap para editar si es necesario corregir fechas
                trailing: const Icon(Icons.edit, size: 18, color: Colors.grey),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ManagePeriodoModal(
                      periodoId: id,
                      currentName: nombre,
                      currentInicio: inicio,
                      currentFin: fin,
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
