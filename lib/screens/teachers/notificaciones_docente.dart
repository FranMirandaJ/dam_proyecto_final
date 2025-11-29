import 'package:flutter/material.dart';

class TeacherNotificationScreen extends StatefulWidget {
  const TeacherNotificationScreen({Key? key}) : super(key: key);

  @override
  State<TeacherNotificationScreen> createState() => _TeacherNotificationScreenState();
}

class _TeacherNotificationScreenState extends State<TeacherNotificationScreen> {
  // Colores del tema
  final Color primaryGreen = const Color(0xFF00C853);
  final Color textDark = const Color(0xFF1F222E);
  final Color textGrey = const Color(0xFF757575);
  final Color bgLight = const Color(0xFFF5F6FA);
  bool isAllSelected = false;

  // Datos para los chips de grupos
  final List<String> groups = ["Grupo 5B", "Grupo 6A", "Grupo 6B", "Todos"];
  // Lista para saber cuáles están seleccionados
  List<String> selectedGroups = [];

  // Datos dummy para el historial
  final List<Map<String, String>> recentHistory = [
    {
      "msg": "Recordatorio: Examen de Programación mañana a las 10:00 AM",
      "group": "Grupo 5B",
      "time": "Hace 2 horas"
    },
    {
      "msg": "Cambio de salón: La clase de hoy será en el laboratorio C-305",
      "group": "Grupo 6A",
      "time": "Ayer"
    },
    {
      "msg": "No olviden subir su proyecto final a la plataforma antes de medianoche",
      "group": "Todos",
      "time": "26 Nov"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // 1. APP BAR
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Notificaciones",
          style: TextStyle(
            color: textDark,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),

      // 2. CUERPO SCROLLEABLE
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // --- SECCIÓN 1: CREAR NUEVA NOTIFICACIÓN ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Nueva Notificación",
                    style: TextStyle(
                      color: textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Subtítulo
                  Text(
                    "Seleccionar grupo",
                    style: TextStyle(color: textGrey, fontSize: 14),
                  ),
                  const SizedBox(height: 10),

                  // Chips de selección múltiple (Wrap para que bajen de línea si no caben)
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: groups.map((group) {

                      final bool isTodosChip = group == "Todos";

                      final bool isSelected = isTodosChip ? isAllSelected : selectedGroups.contains(group);

                      // Bloqueamos los demás si "Todos" está activo
                      final bool isDisabled = !isTodosChip && isAllSelected;

                      return FilterChip(
                        label: Text(group),
                        selected: isSelected,

                        // Si está disabled, pasamos null para que no sea clicable
                        onSelected: isDisabled ? null : (bool selected) {
                          setState(() {
                            if (isTodosChip) {
                              isAllSelected = selected;
                              if (selected) selectedGroups.clear();
                            } else {
                              if (selected) {
                                selectedGroups.add(group);
                              } else {
                                selectedGroups.remove(group);
                              }
                              isAllSelected = false;
                            }
                          });
                        },

                        backgroundColor: bgLight,
                        disabledColor: Colors.grey.shade200,
                        selectedColor: primaryGreen.withOpacity(0.15),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? primaryGreen
                              : (isDisabled ? Colors.grey.shade500 : textGrey),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),

                        checkmarkColor: primaryGreen,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? primaryGreen
                                : Colors.transparent, // Quitamos borde en disabled para que se vea plano
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Campo de Texto
                  TextField(
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "Escribe tu mensaje aquí...",
                      hintStyle: TextStyle(color: textGrey.withOpacity(0.5)),
                      filled: true,
                      fillColor: bgLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Botón Enviar
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Aquí iría tu lógica de Firebase U4
                        debugPrint("Enviando a: $selectedGroups");
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.send_rounded, size: 20),
                      label: const Text(
                        "Enviar Notificación",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- SECCIÓN 2: HISTORIAL (ENVIADAS RECIENTEMENTE) ---
            Text(
              "Enviadas Recientemente",
              style: TextStyle(
                color: textDark,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 15),

            // Lista de items del historial
            // Usamos ListView.builder con shrinkWrap true para que funcione dentro del SingleChildScrollView
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(), // Desactiva el scroll interno para usar el general
              itemCount: recentHistory.length,
              itemBuilder: (context, index) {
                final item = recentHistory[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item["msg"]!,
                        style: TextStyle(
                          color: textDark,
                          fontSize: 15,
                          height: 1.4, // Interlineado para mejor lectura
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Badge del grupo
                          Row(
                            children: [
                              Icon(Icons.people_outline, size: 16, color: textGrey),
                              const SizedBox(width: 4),
                              Text(
                                item["group"]!,
                                style: TextStyle(
                                  color: textGrey,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          // Hora
                          Row(
                            children: [
                              Icon(Icons.access_time, size: 14, color: textGrey),
                              const SizedBox(width: 4),
                              Text(
                                item["time"]!,
                                style: TextStyle(
                                  color: textGrey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),

            // Espacio extra al final para que no quede pegado al borde del cel
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}